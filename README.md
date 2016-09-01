# phidup

phidup is a tool to find duplicate video files by comparing "perceptual hashes", utilizing the [pHash library](http://www.phash.org). It's ~~totally ripped from~~ _inspired by_ [the pHash gem](https://github.com/toy/pHash).

**Be warned:** This is in no way finished or stable, and my first attempt to actually code something useful, so while I welcome criticism and advice, you should not expect everything to "just work".

## Installation

phidup requires libpHash, which seems to be abandoned. Unfortunately it uses deprecated calls to ffmpeg, which makes it quite cumbersome to build, especially as I wasn't even able to get it to honor the explicitly given location of an older ffmpeg on Arch Linux which is rather annoying. Anyway, there's a version of [libpHash](https://github.com/hszcg/pHash-0.9.6) which has some bug fixes, so you can try to build that. I intend to sit down with libpHash and get it to work with a more recent ffmpeg, but that might still take a while.

Once you have libpHash installed, you can run

    $ bundle install
    $ gem build ./phidup.gemspec

And install it with:

    $ gem install ./phidup-0.3.0.gem

## Usage

phidup provides the `phidup` command, which provides (some help) via -h, until I properly describe the usage here.

## Dependencies

* [pHash](http://www.phash.org/download/)
* [ffi](https://github.com/ffi/ffi#readme)
* [sqlite3](https://github.com/sparklemotion/sqlite3-ruby)
* [trollop](https://github.com/ManageIQ/trollop)

## TODO

- [ ] Better and more tests. (Don't do everything by calling the main phidup.rb, test things individually)
- [ ] Better and more documentation (yes, I know. I feel bad.) (somewhat done)
- [ ] Understand why sometimes libpHash returns empty hashes. It's not even that much code, but I still don't understand it..
- [ ] Understand how it sometimes manages to magically crash phidup/ruby silently, without even an exception being raised.
- [ ] Fix the points above.
- [ ] Try to speed it up by removing unnecessary calculations with invavid hashes (mostly done) (By the way: A lot of the heavy lifting isn't even done in ruby, but by libPhash, obviously, so there might not be too much improvement).
- [ ] Look for a faster implementation of the hamming distance.
- [ ] Maybe rewrite it in [crystal](https://crystal-lang.org/). Ruby-like syntax but compiled code? I like it!
- [ ] Improve the code, as well as the general design, while I keep understanding more about ruby and programming in general.


## License

Released under the GPLv3 as required by the license of underlying pHash library.
See `LICENSE` for details.
