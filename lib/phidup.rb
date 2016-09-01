require 'pathname'
require 'trollop'
require 'phidup/philes'

ARGV << '-h' if ARGV.empty?
filetypes = %w( wmv avi mpg mpeg
               ogv flv mkv mp4
               3gp asf divx f4v
               webm m2p ts ps
               m2ts mov qt vob )

# Creates the Phile object and returns it, optionally starts calculating etc.
# @param [Pathname] dbfile Path of the .sqlite file
# @param [String[]] files A list of files
# @option opts [Boolean] :create Whether to create a new database
# @option opts [Boolean] :append Whether to append files too a new database
# @option opts [Boolean] :append Whether to only show results
# @return [Phile] phile 
def open_phile(dbfile, files,  opts)
  phile = Phidup::Phile.new(dbfile)
  phile.create_db(files.uniq) if opts[:create]
  phile.append(files.uniq) if opts[:append]
  phile.init_scan unless opts[:results]
  phile.calc_dists unless opts[:results]
  phile
end

# scans the given directory for files of filetype, optionally recurses
# @param [String] dir path to a directory
# @param [String[]] filetypes List of filetypes to include
# @option opts [Boolean] :recursive Whether to recursively scan subdirectories
# @return [String[]] files a list of files
def scan(dir, filetypes, opts)
  files = []
  dr = Pathname.new(dir).expand_path
  return files << dr unless dr.directory?
  dr.each_entry do |d|
    next if d.to_s == '.' || d.to_s == '..'
    exp = d.expand_path(dr).to_s
    if d.expand_path(dr).directory?
      files << scan(exp, filetypes, opts).flatten if opts[:recursive]
      next
    end
    files << exp if filetypes.include?(d.extname.sub('.', ''))
  end
  files
end

# outputs possible duplicates
# @param [Phile] phile a Phile object
def show_dups(phile, threshold)
  duplist = phile.dups(threshold)
  puts 'Possible duplicates:'
  duplist.each do |dup|
    next if dup.nil?
    dup.each { |a| puts a }
    puts ''
  end
  # puts duplist.length
end

# TODO: exclude hidden folders/files‽

opts = Trollop.options do
  banner <<-EOS
  Find duplicates of video files utilizing perceptive hashes via pHash.

    phidup [options] dir1, dir2, ...

    EOS
  opt :resume, 'Resume an interrupted previous run. Use --dbfile to specify a different database file than the default one.', short: 'R'
  opt :recursive, 'Recursively scan directories.', short: 'r'
  opt :filetypes, 'Only scan the given filetypes instead of pretty much everything ffmpeg can work with. (comma seperated: "mkv,webm,..")', short: 't', type: String
  opt :dbfile, 'Use the given file to store results and progress instead of the default one. (Will be created if it doesn\'t exist.)', type: String, default: '~/phidup.sqlite', short: 'd'
  opt :results, 'Show results from a previous run.'
  opt :threshold, 'What similarity (hamming distance) should count as a potential duplicate?', type: Integer, default: 21, short: 'T'
  opt :append, 'Scan more folders and add to dbfile', short: 'a'
  opt :merge, 'Merge another db in the current db', short: 'm', type: String
end

filetypes += opts[:filetypes].split(',') unless opts[:filetypes].nil?
filetypes.uniq!

files = [] # otherwise Phile.new couldn't get an empty [] in case you resume
files = ARGV.map { |d| scan(d, filetypes, opts) } unless ARGV.empty? # rm argv.empty??
files.flatten!

dbfile = Pathname.new(opts[:dbfile]).expand_path

unless opts[:resume] || opts[:append] || opts[:results] || opts[:merge]
  if dbfile.exist?
    puts "#{dbfile} exists!"
    exit
  end
  open_phile(dbfile, files, create: true)
end

if opts[:resume] || opts[:append] || opts[:results] || opts[:merge]
  unless dbfile.exist?
    puts "#{dbfile} doesn't exist!"
    exit
  end
  phile = open_phile(dbfile, files, opts)
  if opts[:merge_given]
    other_dbfile = Pathname.new(opts[:merge]).expand_path
    other_phile = open_phile(other_dbfile, files, opts)
    phile.merge(other_phile)
  end
  show_dups(phile, opts[:threshold]) if opts[:results]
end
