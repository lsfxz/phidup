# require 'phash'
# require 'phash/video'
require 'ffi'

module Phidup
  extend FFI::Library

  ffi_lib ENV.fetch('PHASH_LIB', 'pHash')

  attach_function :ph_dct_videohash, [:string, :pointer], :pointer, blocking: true
  attach_function :ph_hamming_distance, [:ulong, :ulong], :int, blocking: true

  # Handles phash data and the invocation of libphash
  # @attr [String] path path to the file the phash belongs to
  # @attr [Integer] id id of the file in the database
  # @attr [FFI::MemoryPointer] phash ulong array, handled by FFI
  # @attr [Integer] length length size of the @phash array
  class Phobject
    attr_reader :path, :id, :phash, :length
    # @param [String] path path to a file
    # @option opts [Bignum[]] :ph_array An array oh phash data
    def initialize(path, options = {})
      @path = path
      @id = options[:id]

      if !options[:ph_array]
        # super(path)
        compute_phash
      else
        # maybe I should already check after computation
        # and so weed out invalid files before commiting them
        # to the database? TODO
        # puts options[:ph_array].class
        attach_array(options[:ph_array]) if valid_hash?(options[:ph_array])
      end
    end

    # calls libphash to get a perceptive hash of the file
    def compute_phash
      hash_data_length_p = FFI::MemoryPointer.new :int
      hash_data = Phidup.ph_dct_videohash(@path, hash_data_length_p)
      if hash_data
        hash_data_length = hash_data_length_p.get_int(0)
        hash_data_length_p.free

        @phash = hash_data
        @length = hash_data_length
        # Phash::VideoHash.new(hash_data, hash_data_length)
      end
    end

    #dup[1] Calculates the hamming distance between two Phobjects
    # @param [Phobject] hash_b another Phobject
    # @return [Float] Hamming Distance
    def hamming(hash_b)
      if @length <= hash_b.length
        min = @phash
        max = hash_b.phash
        min_len = @length
        max_len = hash_b.length
      else
        min = hash_b.phash
        max = @phash
        min_len = hash_b.length
        max_len = @length
      end
      dists = 0.0

      min_ary = min.read_array_of_ulong(min_len)
      max.read_array_of_ulong(max_len).each_with_index do |frst, i|
        i >= min_len ? dists += Phidup.ph_hamming_distance(frst, 0) : dists += Phidup::ph_hamming_distance(frst, min_ary[i])
      end
      dists / max_len
    end

    def valid_hash?(ph_array)
      # puts (ph_array.nil? || ph_array.include?(0))? false : true
      # puts ph_array.size
      (ph_array.nil? || ph_array.include?(0))? false : true
      # return false if ph_array.nil? || ph_array.include?(0)
      # return true
    end

    # attaches existing phash data as an FFI-Array
    def attach_array(ph_array)
      phdata = FFI::MemoryPointer.new(:ulong, ph_array.length)
      phdata.write_array_of_ulong(ph_array)

      @phash = phdata
      @length = ph_array.length
    end
  end
end
