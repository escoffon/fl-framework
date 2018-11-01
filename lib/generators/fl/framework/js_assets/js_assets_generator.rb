require 'json'

module Fl::Framework
  class JsAssetsGenerator < Rails::Generators::Base
    APP_ROOT = File.join('app', 'assets', 'javascripts', 'fl', 'framework')
    VENDOR_ROOT = File.join('vendor', 'assets', 'javascripts', 'fl', 'framework')
    APP_ASSETS = [
      {
        from: File.join(APP_ROOT, 'fl.js'),
        to: File.join(VENDOR_ROOT, 'fl.js'),
      },
      {
        from: File.join(APP_ROOT, 'model_factory.js'),
        to: File.join(VENDOR_ROOT, 'model_factory.js'),
      },
      {
        from: File.join(APP_ROOT, 'object_system.js'),
        to: File.join(VENDOR_ROOT, 'object_system.js'),
      },
      {
        from: File.join(APP_ROOT, 'api_services.js'),
        to: File.join(VENDOR_ROOT, 'api_services.js'),
      }
    ]

    PACKAGE_FILE = 'package.json'
    
    source_root File.expand_path('templates', __dir__)

    def run_generator()
      @gem_root = File.expand_path('../../../../..', __dir__)

      copy_assets()
      generate_js_index()
      add_yarn_packages()
    end

    private
    
    def copy_assets
      _copy_assets(APP_ASSETS, @gem_root, destination_root)
    end

    def generate_js_index
      outfile = File.join(destination_root, 'vendor', 'assets', 'javascripts', 'fl', 'framework', 'index.js')
      template('fl_framework_index.js', outfile)
    end

    def _copy_assets(assets, iroot, oroot)
      assets.each do |a|
        ifile = File.join(iroot, a[:from])
        ofile = File.join(oroot, a[:to])
        copy_file(ifile, ofile)
      end
    end

    def _list_packages(root)
      jp = File.open(File.join(root, PACKAGE_FILE)) { |f| JSON.parse(f.read) }

      {
        full: jp['dependencies'],
        names: jp['dependencies'].reduce([ ]) do |acc, (k, v)|
          acc << k
          acc
        end
      }
    end

    def _package_entry(name, version)
      "    \"#{name}\": \"#{version}\""
    end

    def _update_dependencies(dependencies, gem_p)
      num_updates = 0

      gem_p[:names].each do |n|
        if dependencies.has_key?(n)
          if dependencies[n] != gem_p[:full][n]
            say_status('update', "install new version #{gem_p[:full][n]} for package #{n}")
            dependencies[n] = gem_p[:full][n]
            num_updates += 1
          end
        else
          say_status('create', "add package #{n} with version #{gem_p[:full][n]}")
          dependencies[n] = gem_p[:full][n]
          num_updates += 1
        end
      end

      d = dependencies.keys.sort.reduce([ ]) do |acc, n|
        acc << _package_entry(n, dependencies[n])
        acc
      end

      [ num_updates, d.join(",\n") + "\n" ]
    end
    
    def _update_package_file(gem_p)
      pkg_file = File.join(destination_root, PACKAGE_FILE)
      pkg = File.open(File.join(destination_root, PACKAGE_FILE)) { |f| JSON.parse(f.read()) }
      num_updated, d_output = _update_dependencies(pkg['dependencies'], gem_p)

      return if num_updated < 1
      
      plines = File.open(pkg_file) { |f| f.readlines() }
      output = ''
      while plines.length > 0
        l = plines.shift
        
        if l =~ /"dependencies":/
          output << l
          output << d_output

          while plines.length > 0
            l = plines.shift
            if l =~ /}/
              output << l
              break
            end
          end
        else
          output << l
        end
      end

      say_status('update', "update #{PACKAGE_FILE}")
      File.open(pkg_file, 'w') { |f| f.write(output) }

      say_status('warning', "please run yarn to refresh the package distribution", :yellow)
    end

    def add_yarn_packages()
      gem_p = _list_packages(@gem_root)

      if File.exists?(File.join(destination_root, PACKAGE_FILE))
        _update_package_file(gem_p)
      else
        @app_name = if Rails.application.config.session_options[:key] =~ /^_(.*)_session/
                      Regexp.last_match[1]
                    else
                      'Rails application'
                    end
        d = gem_p[:names].sort.reduce([ ]) do |acc, n|
          acc.push(_package_entry(n, gem_p[:full][n]))
          acc
        end
        @dependencies = d.join(",\n")

        template('package.json', File.join(destination_root, PACKAGE_FILE))
      end
    end
  end
end

