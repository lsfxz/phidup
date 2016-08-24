require 'test_helper'
require 'sqlite3'
require 'fileutils'

class TestPhidup < Minitest::Test
  @db = []
  describe 'phidup invocation' do
    before do
      ARGV.replace(["-r", "-d", "./test/test.sqlite", "./test/phtestfiles/"])
      require 'phidup'
      @db = SQLite3::Database.new('./test/test.sqlite')
    end
    #after do
      #FileUtils.rm('./test.sqlite')
    #end

    it 'should (recursively) scan the test dir and create a db' do
      @db.execute('SELECT * FROM tblphiles').length.must_equal 12
    end
  end
end



# class TestPhilesMerge < Minitest::Test
  # @db = []
  # @db2 = []
  # describe 'merge' do
    # before do
      # ARGV.replace(['-d', './test/testm.sqlite', './test/phtestfiles/', './test/phtestfiles/phtestfiles2/jug-120.mp4'])
      # load 'phidup.rb'
      # ARGV.replace(['-d', './test/testm_2.sqlite', './test/phtestfiles/phtestfiles2/'])
      # load 'phidup.rb'
      # # @db2 = SQLite3::Database.new('./test/testm_2.sqlite')
      # ARGV.replace(['-d', './test/testm.sqlite', '-m', './test/testm_2.sqlite'])
      # load 'phidup.rb'
      # @db = SQLite3::Database.new('./test/testm.sqlite')
    # end

    # it 'should (recursively) scan the test dir and create a db' do
      # @db.execute('SELECT * FROM tblphiles').length.must_equal 12
    # end
  # end
# end
