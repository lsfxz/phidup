require 'yaml'
require 'pathname'
require 'sqlite3'
require 'phidup/phobject'

module Phidup
  # Handles the database files and file pathes,
  # initial scanning and comparing of .Phobjects.
  class Phile
    # Opens database file and fills it, if necessary..
    #
    # @param files [String[]] Pathes to files.
    # @option opts [Integer] :threshold Hamming distance from which on a file
    #   is considered a duplicate.
    # @option opts [Boolean] :append Whether to append files to the db.
    # @option opts [Boolean] :resume Whether to resume a scanning process.
    # @option opts [Boolean] :results Whether to show the results/duplicates.
    # @option opts [Boolean] :merge Whether to merge with another db.
    def initialize(files, opts)
      @files = files
      @threshold = opts[:threshold]
      dbfile = Pathname.new(opts[:dbfile]).expand_path
      if (opts[:resume] || opts[:results] || opts[:append]) && !dbfile.exist?
        puts "#{dbfile} does not exist!"
        exit
      elsif !(opts[:resume] || opts[:results] || opts[:append] || opts[:merge_given]) && dbfile.exist?
        puts "#{dbfile} exists!"
        exit
      end

      @db = SQLite3::Database.new(dbfile.to_s)
    end

    # Creates the tables in the database and fills it with the file pathes.
    def create_db
      @db.execute_batch <<-EOS
      PRAGMA foreign_keys;
      CREATE TABLE tblphiles
      (
        id INTEGER PRIMARY KEY NOT NULL,
        path TEXT UNIQUE NOT NULL
      );

      CREATE TABLE tbl_philes_distances
      (
        id_1 INTEGER NOT NULL,
        id_2 INTEGER NOT NULL,
        distance FLOAT,
        PRIMARY KEY (id_1, id_2),
        FOREIGN KEY (id_1) REFERENCES tblphiles(id),
        FOREIGN KEY (id_2) REFERENCES tblphiles(id)
      );

      CREATE TABLE tbl_philes_hashes
      (
        id INTEGER PRIMARY KEY NOT NULL,
        hash_array BLOB,
        FOREIGN KEY (id) REFERENCES tblphiles(id)
      );
      EOS

      @files.each { |f| store_path(f.to_s) }

    end

    # Starts creating the perceptive hashes and saves them in the database
    def init_scan
      files = @db.execute('SELECT id, path FROM tblphiles WHERE id NOT IN (SELECT id FROM tbl_philes_hashes)')

      puts "files left: #{files.length}"

      files.each do |f|
        ph = Phobject.new(f[1])
        # puts "noping out of here" if ph.length == 0 || ph.phash.nil?
        next if ph.length == 0 || ph.phash.nil? # is this enough? TODO
        ph_array = []
        # begin
        ph.phash.read_array_of_ulong(ph.length).each do |h|
          ph_array << h
        end
        # shouldn't occur anymore after sorting out the bad ones above
        # rescue FFI::NullPointerError => onoz
        # puts "Something went wrong: "
        # puts onoz.inspect
        # puts "File: #{ph.path}"
        # end
        store_phash(ph_array, f[0])
        puts "#{f[0]}/#{files.length} done." # THIS IS, OF COURSE, BULLSHIT! FIX ME !! TODO
      end
    end

    # Appends further files to an existing database
    def append
      philes = @db.execute('SELECT path FROM tblphiles').flatten
      @files -= philes
      @files.each { |f| store_path(f) }
    end

    # Calculates the hamming distances between the files and stores them in
    # the database
    def calc_dists
      each do |phob|
        each do |phob_2|
          next if phob.id == phob_2.id
          # skip if already calculated
          next if @db.execute('SELECT distance FROM tbl_philes_distances WHERE (id_1 == ? AND id_2 == ?) OR (id_2 == ? AND id_1 == ?)', [phob.id, phob_2.id, phob.id, phob_2.id]).length > 0
          dist = phob.hamming(phob_2)
          store_dist(phob.id, phob_2.id, dist)
        end
      end
    end

    # Returns the files from the database which, according to @threshold,
    # are potential duplicates
    # @return [String[]] an array of the pathes of potential duplicates
    def dups
      # TODO use each dist?
      duplist = @db.execute('SELECT id_1, id_2 FROM tbl_philes_distances WHERE distance <= ?', @threshold)
      # smt_pharray = @db.prepare('SELECT hash_array FROM tbl_philes_hashes WHERE id == ?')

      # puts 'Dup:'
      duplist.map do |dup|
        phob = phob_by_id(dup[0])
        phob2 = phob_by_id(dup[1])
        next if phob.length == 0 || phob.phash.nil?
        next if phob2.length == 0 || phob2.phash.nil?

        # pharr = smt_pharray.execute(phob.id).flatten[0]
        # pharr2 = smt_pharray.execute(phob2.id).flatten[0]
        # puts "debug: #{phob1.length}, #{phob2.length}"
        # puts "#{phob.path} #{phob2.path}"
        [phob.path, phob2.path]
      end
    end

    # Merges (usable/valid) Data of another Phile object in the current one
    # @param other_phile [Phobject] The Phile object containing the other db
    def merge(other_phile)
      other_phile.is_a?(Phile) or raise ArgumentError.new('other_phile is not a Phile')
      mappings = {}
      other_phile.each do |phob|
        new_id = store_path(phob.path)
        next if new_id.nil?
        ph_array = []
        phob.phash.read_array_of_ulong(phob.length).each do |h|
          ph_array << h
        end
        # puts "about to store phash: #{new_id}"
        store_phash(ph_array, new_id)

        mappings[phob.id] = new_id
      end

      other_phile.each_dist do |id1, id2, dist|
        next if mappings[id1].nil? || mappings[id2].nil?
        store_dist(mappings[id1], mappings[id2], dist)
      end
    end

    # Returns the Phobject for the given id
    # @param id [Fixnum] The id the Phobject should be returned for
    # @return [Phobject] The Phobject for the given id
    def phob_by_id(id)
      path = @db.execute('SELECT path FROM tblphiles WHERE id == ?', [id]).flatten[0]
      ph_array = @db.execute('SELECT hash_array FROM tbl_philes_hashes WHERE id == ?', [id]).flatten[0]
      Phobject.new(path, id: id, ph_array: YAML.load(ph_array))
    end

    # Returns an Enumerator if no block is given, otherwise it iterates
    # through the Phobjects.
    # @return [Enumerator] unless given a block
    def each
      return enum_for(:each) unless block_given?
      files = @db.execute('SELECT id FROM tblphiles WHERE id IN (SELECT id FROM tbl_philes_hashes)')
      files.each do |id|
        yield phob_by_id(id)
      end
    end

    # Returns an Enumerator if no block is given, otherwise it iterates.
    # through the already calucated hamming distances between the files.
    # @return [Enumerator] unless given a block.
    def each_dist
      return enum_for(:each_dist) unless block_given?
      # is this too big for mem?
      dists = @db.execute('SELECT id_1, id_2, distance FROM tbl_philes_distances WHERE id_1 IN (SELECT id FROM tbl_philes_hashes)')
      dists.each do |id1, id2, dist|
        yield id1, id2, dist
      end
    end

    # Adds a new file/path to the db.
    # @param path [String] The path of the file to be added.
    # @return [nil] if the path is already in the database.
    # @return [Fixnum] if successful.
    def store_path(path)
      # TODO: catch unique-constraint-exception?
      # puts @db.execute('SELECT id FROM tblphiles WHERE path == ?', [path]).empty?
      return nil unless @db.execute('SELECT id FROM tblphiles WHERE path == ?', [path]).empty?
      @db.execute('INSERT INTO tblphiles (path) VALUES (?)', [path])
      # returns id
      @db.execute('SELECT id FROM tblphiles WHERE path == ?', [path])
    end

    # Stores an array of pHash data and its id in the database.
    # @param ph_array [Bignum[]] An array with the pHash data.
    # @param id [Fixnum] The corresponding id to the hash.
    def store_phash(ph_array, id)
      @db.execute('INSERT INTO tbl_philes_hashes (id, hash_array) VALUES(?, ?)', [id, YAML.dump(ph_array)])
    end

    # Stores the hamming distance between to files specified by id.
    # @param id1 [Fixnum] The id of the first file.
    # @param id2 [Fixnum] The id of the second file.
    # @param distance [Float] The hamming distance between both files.
    # @return [nil] if already in database
    def store_dist(id1, id2, distance)
      # TODO: catch unique-constraint-exception?
      return nil unless @db.execute('SELECT distance FROM tbl_philes_distances WHERE id_1 == ? AND id_2 == ?', [id1, id2]).empty?
      @db.execute('INSERT INTO tbl_philes_distances (id_1, id_2, distance) VALUES (?, ?, ?)', [id1, id2, distance])
      # returns id
    end
  end
end
