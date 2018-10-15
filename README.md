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
## How to run tests.

Since some tests in this gem require a Rails application, one was created in `spec/testapp`.
To run the tests, `cd spec/testapp` and then run Rspec from that directory.
You will need to run migrations first: `RAILS_ENV=test bin/rake db:migrate`.

Note that the test scripts reside in `spec/testapp/spec`.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
