## The fl-framework gem

This gem is a mountable engine that contains a collection of modules, classes, and utilities that define a
framework for Rails application implementation.

## Usage
This here is a short description on engine usage.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'fl-framework'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install fl-framework
```

## Testing

### Ruby/Rails tests

Ruby/Rails tests are currently in flux; some are run using the standard Rails unit testing tool,
while other have migrated to [RSpec](http://rspec.info). The tests that have not yet migrated may not
work.

Since some tests in this gem require a Rails application, one was created in `spec/testapp`.
To run the tests, `cd spec/testapp` and then run Rspec from that directory.
You will need to run migrations first: `RAILS_ENV=test bin/rake db:migrate`.

Note that the test scripts reside in `spec/testapp/spec`.

### Javascript tests

The gem uses [Mocha](https://mochajs.org) for Javascript tests. The test files are in the `mocha`
directory, and the script `scripts/test_js.sh` is the main driver:

```bash
$ ./scripts/test_js.sh
running test command: node_modules/.bin/mocha --recursive --reporter spec --file mocha/utils/setup.js mocha/db mocha/unit
Warning: Could not find any test files matching pattern: mocha/db


  fl.model_factory module
    loading
      ✓ should register the FlBaseModelExtension extension
      ✓ should register the FlModelBase class
    FlModelBase
      creation
        ✓ with new should create an instance of the model class
...
        ✓ should return a single object on single input (with explicit ctor)
        ✓ should return an an object array on array input
        ✓ should return an an object array on array input (with explicit ctor)


  63 passing (60ms)

$
```

## Documentation

### Ruby documentation

Documentation for the Ruby/Rails components is generated using the [Yard](https://yardoc.org)
documentation tool:

```bash
$ yard
[warn]: @param tag has unknown parameter name: op 
    in file `lib/fl/framework/service/comment/active_record.rb' near line 44
...
[warn]: In file `lib/fl/framework/controller/access.rb':29: Cannot resolve link to #error_response from text:
	...{#error_response}...
Files:          73
Modules:       100 (    1 undocumented)
Classes:        40 (    0 undocumented)
Constants:      27 (    0 undocumented)
Attributes:     32 (    0 undocumented)
Methods:       367 (    0 undocumented)
 99.82% documented
$ 
```

### Javascript documentation

Documentation for the Javascript components is generated using a customized and enhanced version of
[Dgeni](https://github.com/angular/dgeni) and [dgeni-packages](https://github.com/angular/dgeni-packages).
It uses a [Gulp](https://gulpjs.com) process to run the document generator:

```bash
$ gulp
[14:48:37] Using gulpfile ~/src/gems/fl/fl-framework/gulpfile.js
[14:48:37] Starting 'default'...
[14:48:37] Starting 'clean-js-docs'...
[14:48:37] Finished 'clean-js-docs' after 16 ms
[14:48:37] Starting 'js-docs'...
[14:48:37] Starting 'clean-js-docs'...
[14:48:37] Finished 'clean-js-docs' after 504 μs
[14:48:37] Starting 'dgeni-docs'...
info:    running processor: readFilesProcessor
info:    running processor: extractJSDocCommentsProcessor
info:    running processor: parseTagsProcessor
...
info:    running processor: writeFilesProcessor
info:    running processor: checkAnchorLinksProcessor
[14:48:37] Finished 'dgeni-docs' after 706 ms
[14:48:37] Finished 'js-docs' after 708 ms
[14:48:37] Finished 'default' after 726 ms
$ 
```
The configuration file `doc/dgeni/conf.js` sets the output directory at `public/doc/out/dgeni`.

Since the document generator is Node-based, you will have to run [yarn](https://yarnpkg.com) or
[npm](https://www.npmjs.com) to build the package distribution.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
