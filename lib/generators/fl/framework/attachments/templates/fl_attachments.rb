# Created by fl:framework:attachments generator
#
# Standard Paperclip configurations for various fl-framework Paperclip attachment types.
#
# Defines these types:
# :fl_framework_images configures images used for pictures: creates large preview thumbnails
# :fl_framework_avatar configures images used for avatars: creates smaller preview thumbnails
# :fl_framework_thumbnail configures images used as thumbnails: similar to avatar, but with smaller sizes
#
# The production environment uses AWS S3 for storage.
# We also create three production clones: staging, demo, and localprod, which therefore also use S3.
# The S3 file is in config/paperclip_s3.yml.
#
# Since the configuration is set up to use URI obfuscation, you will have to create a hash secret;
# the configuration comments it out to trigger an error until you do so.

require 'fl/framework/attachment/configuration'
require 'paperclip_processors/floopnail.rb'

cfg = Fl::Framework::Attachment.config

cfg.defaults(nil, {
               convert_options: {
                 all: "-auto-orient"
               },
               processors: [ :floopnail ],

               # hash_secret: 'replace with a string containing the hash secret and uncomment',
               hash_data: ":class/:attachment/:id/:style_:basename",
               default_url: '/static/paperclip/:class/:attachment/default_:style.png',
               processing_image_url: '/static/paperclip/:class/:attachment/processing_:style.png',

               storage: :filesystem,
               url: "/pc/:rails_env/:class/:attachment/:id_partition/:hash.:extension",
               path: ":rails_root/public:url"
             })

# Standard parameters for images
cfg.defaults(:fl_framework_image, {
               styles: {
                 xlarge: "1200x1200>",
                 large: "600x600>",
                 medium: "400x400>",
                 small: "200x200>",
                 thumb: "100x100>" ,
                 iphone: { geometry: "64x64>" }
               },
               default_style: :thumb
             })
cfg.merge!('production', :fl_framework_image, {
             storage: :s3,
             s3_protocol: 'https',
             s3_credentials: File.join(::Rails.root.to_s, 'config', 'paperclip_s3.yml'),
             path: "pc/:class/:attachment/:id_partition/:hash.:extension",
             url: ':s3_domain_url'
           })
cfg.clone('production', :fl_framework_image, 'staging')
cfg.clone('production', :fl_framework_image, 'demo')
cfg.clone('production', :fl_framework_image, 'localprod')

# Standard parameters for avatars
cfg.defaults(:fl_framework_avatar, {
               styles: {
                 xlarge: { geometry: "200x200>", keep_size: true, format: 'png' },
                 large: { geometry: "72x72>", keep_size: true, format: 'png' },
                 medium: { geometry: "48x48>", keep_size: true, format: 'png' },
                 thumb: { geometry: "32x32>", keep_size: true, format: 'png' },
                 list: { geometry: "24x24>", keep_size: true, format: 'png' }
               },
               convert_options: {
                 xlarge: "-strip -background transparent",
                 large: "-strip -background transparent",
                 medium: "-strip -background transparent",
                 thumb: "-strip -background transparent",
                 list: "-strip -background transparent"
               },
               default_style: :medium
             })
cfg.merge!('production', :fl_framework_avatar, {
             storage: :s3,
             s3_protocol: 'https',
             s3_credentials: File.join(::Rails.root.to_s, 'config', 'paperclip_s3.yml'),
             s3_storage_class: {
               xlarge: :REDUCED_REDUNDANCY,
               large: :REDUCED_REDUNDANCY,
               medium: :REDUCED_REDUNDANCY,
               thumb: :REDUCED_REDUNDANCY,
               list: :REDUCED_REDUNDANCY
             },
             path: "pc/:class/:attachment/:id_partition/:hash.:extension",
             url: ':s3_domain_url'
           })
cfg.clone('production', :fl_framework_avatar, 'staging')
cfg.clone('production', :fl_framework_avatar, 'demo')
cfg.clone('production', :fl_framework_avatar, 'localprod')

# Standard parameters for thumbnails
cfg.defaults(:fl_framework_thumbnail, {
               styles: {
                 snapshot: { geometry: "100x100>", keep_size: true, bg_color: 'xc:transparent' },
                 large: { geometry: "72x72>", keep_size: true, bg_color: 'xc:transparent' },
                 medium: { geometry: "48x48>", keep_size: true, bg_color: 'xc:transparent' },
                 thumb: { geometry: "32x32>", keep_size: true, bg_color: 'xc:transparent' }
               },
               default_style: :snapshot,
             })
cfg.merge!('production', :fl_framework_thumbnail, {
             storage: :s3,
             s3_protocol: 'https',
             s3_credentials: File.join(::Rails.root.to_s, 'config', 'paperclip_s3.yml'),
             path: "pc/:class/:attachment/:id_partition/:hash.:extension",
             url: ':s3_domain_url'
           })
cfg.clone('production', :fl_framework_thumbnail, 'staging')
cfg.clone('production', :fl_framework_thumbnail, 'demo')
cfg.clone('production', :fl_framework_thumbnail, 'localprod')
