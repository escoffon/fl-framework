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
    ]
    
    source_root File.expand_path('templates', __dir__)

    def run_generator()
      copy_assets()
      generate_js_index()
    end

    private
    
    def copy_assets
      gem_root = File.expand_path('../../../../..', __dir__)

      _copy_assets(APP_ASSETS, gem_root, destination_root)
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
  end
end

