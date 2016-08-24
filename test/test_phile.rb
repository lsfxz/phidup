require 'test_helper'
require 'sqlite3'
require 'phidup/philes'
require 'fileutils'

class TestPhiles < Minitest::Test
  @db = []
  describe 'phile' do
    before do
      ARGV.replace(['-r', '-d', './test/test.sqlite', './test/phtestfiles/'])
      require 'phidup'
      @db = SQLite3::Database.new('./test/test.sqlite')
    end

    it 'should fill the db with hashes and their hamming distances' do
      @db.execute('SELECT * FROM tbl_philes_distances WHERE distance <= 21').length.must_equal 22
    end
  end

  @db = []
  @db2 = []
  describe 'merge' do
    before do
      ARGV.replace(['-d', './test/testm.sqlite', './test/phtestfiles/', './test/phtestfiles/phtestfiles2/jug-120.mp4'])
      load 'phidup.rb'
      ARGV.replace(['-d', './test/testm_2.sqlite', './test/phtestfiles/phtestfiles2/'])
      load 'phidup.rb'
      ARGV.replace(['-d', './test/testm.sqlite', '-m', './test/testm_2.sqlite'])
      load 'phidup.rb'
      @db = SQLite3::Database.new('./test/testm.sqlite')
    end

    it 'should scan the test dirs, create dbs and merge two dbs, excluding duplicates' do
      @db.execute('SELECT * FROM tblphiles').length.must_equal 12
    end
  end
end
