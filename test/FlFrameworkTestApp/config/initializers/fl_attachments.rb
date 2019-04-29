require 'fl/framework/attachment/configuration'

cfg = Fl::Framework::Attachment.config

cfg.defaults(:fl_image, {
               styles: {
                 xlarge: { resize: "1200x1200>", strip: true, background: 'rgba(255,255,255,0)' },
                 large: { resize: "600x600>", strip: true, background: 'rgba(255,255,255,0)' },
                 medium: { resize: "400x400>", strip: true, background: 'rgba(255,255,255,0)' },
                 small: { resize: "200x200>", strip: true, background: 'rgba(255,255,255,0)' },
                 thumb: { resize: "100x100>", strip: true, background: 'rgba(255,255,255,0)' },
                 iphone: { resize: "64x64>", strip: true, background: 'rgba(255,255,255,0)' },
                 original: { }
               },
               default_style: :thumb
             })

cfg.defaults(:fl_avatar, {
               styles: {
                 xlarge: { resize: "200x200>", strip: true, background: 'rgba(255,255,255,0)' },
                 large: { resize: "72x72>", strip: true, background: 'rgba(255,255,255,0)' },
                 medium: { resize: "48x48>", strip: true, background: 'rgba(255,255,255,0)' },
                 thumb: { resize: "32x32>", strip: true, background: 'rgba(255,255,255,0)' },
                 list: { resize: "24x24>", strip: true, background: 'rgba(255,255,255,0)' },
                 original: { strip: true, background: 'rgba(255,255,255,0)' }
               },
               default_style: :medium
             })

cfg.defaults(:fl_generic_file, {
               styles: {
                 original: { }
               },
               default_style: :original
             })
