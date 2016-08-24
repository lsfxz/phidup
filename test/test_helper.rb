$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minitest/autorun'
require 'minitest/reporters'
require 'fileutils'
# require 'shoulda/context'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
Minitest.after_run do
  FileUtils.rm_f('./test/test.sqlite')
  FileUtils.rm_f('./test/testm.sqlite')
  FileUtils.rm_f('./test/testm_2.sqlite')
end
