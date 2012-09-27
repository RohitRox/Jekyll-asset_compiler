#
# Jekyll Asset Compiler
#
# Author : Rohit Rox
# Repo   : http://github.com/rohitrox/jekyll-asset_compiler
# License: MIT, see LICENSE file
#
require 'yaml'
require 'digest/md5'
require 'net/http'
require 'uri'
require "yui/compressor"
require 'pry'
module Jekyll

	class AssetGen < Generator
		safe true
		@@bundle_ext = ['.js', '.css']
		@@bundle_hash = []

		def generate(site)
			@files = {}
			bundle = false
			@src = site.source
			bundle_dir = @src + '/_bundle'
			puts "Asset Bundler"

				if Dir.glob(bundle_dir).empty?

					puts "Bundle directory not created , creating one ... "
					FileUtils.mkdir_p(bundle_dir)
					puts "Add your css and js bundle files here. See doc."

				elsif Dir.glob(bundle_dir + '/*').empty?
					puts "No Bundle files found ... "
				
				else
					puts "Found "+Dir.glob(bundle_dir + '/*').size.to_s+" bundle file(s)"
					FileUtils.mkdir_p(@src + '/bundles')
					bundle = true
				end

			if bundle
				process_file( Dir.glob(bundle_dir + '/*'))
			end

		end # end of generate

		def process_file(files)
			@files = files
			valid_files = []
			@files.each do |f|
				f_name = f.split('/').last()
				if /^bundle/.match(f_name) && @@bundle_ext.include?(f.match(/\.([^\.]+)$/)[0])
					valid_files << f
				else
					puts "Ignoring #{f} is not valid. Bundle file must start with bundle and should hav .js or .css ext."	
				end
			end

			load_files(valid_files)

		end # end of process_file

		def load_files(files)
			bundles = {}
			files.each do |f|
				raw_markup = File.read(f)
				begin
		        	assets = YAML::load(raw_markup)
		      	rescue
		        	puts <<-END
			              Asset Bundler - Error: Problem parsing a YAML bundle
			              #{raw_markup}

			              #{$!}
			            END
		      	end
		      	bundles[f.split('/').last()] = assets
		     end
		     
		     compile_assets(bundles)

		end # end of load_files

		def compile_assets(bundles)
			
			bundles.each do |k,v|
				f_name = k.to_s	
				f_path = @src+"/bundles/"+f_name.gsub('bundle', "bundled")
				assefier(v, f_name)
			end
			puts "Asset bundler end."
		end # end of compile_assets

		def assefier(v, f_name)
			f_path = @src+"/bundles/"+f_name.gsub('bundle', "bundled")
			f_ext = File.extname(f_path)

			if f_ext == ".js"
				current_ext = ".js"
				compressor = YUI::JavaScriptCompressor.new
			elsif f_ext == '.css'
				current_ext = ".css"
				compressor = YUI::CssCompressor.new
			end
				
			file_arr = v.split(' ')
			f_ext = file_arr.map{ |f| File.extname(f) }

			if f_ext.uniq.length > 1 && current_ext == f_ext.uniq[0]
				puts "Aborting. There is js and css mixmax in #{f_name}. Please fix it first. "
			elsif @@bundle_ext.include?(f_ext.uniq[0])

				compressed = ""
				file_arr.each do |f|
								puts "process #{f} ... "
	
								if f =~ /^(https?:)?\/\//i
								
								f = "http:#{f}" if !$1
								f.sub!( /^https/i, "http" ) if $1 =~ /^https/i
								puts "Getting files from #{f} ... "
								content = (Net::HTTP.get(URI(f)))

								else
									if File.exists?(File.join(@src, f))
										content = File.read(File.join(@src, f))
									else
										puts "#{f} not found. Aborting."
										return
									end
								end
								begin
								compressed_content = compressor.compress(content)
								compressed = compressed.concat(compressed_content)
								rescue
									puts "compression failed for #{f} ..."
								end
				end

				digest_content = Digest::SHA1.hexdigest(compressed)
	
				File.exists?(f_path) ? bundle_file_hash = Digest::SHA1.hexdigest(File.read(f_path)) : bundle_file_hash = ""
				if bundle_file_hash == digest_content
					puts "no change in #{f_name}"
				else
					puts "changes found , processing ..."
					File.open(f_path,'w'){ |f|
						f.write(compressed)				
					}
				
				end
			else
				puts "Aborting. Unsupported file in #{f_name} bundle list. Please fix it first"
				return
			end
			


		end # end of assefier

	end # end of AssetGen class

	class AssetTag < Liquid::Block

		def initialize(tag_name, text, tokens)
      		super    
    	end

		def render(context)
      		src = context.registers[:site].source
      		includes = nodelist[0].split(',').map{|n| n.gsub(' ','')}
      		markup = ""
      		includes.each do |i|
      			bundled_name = "bundled_"+i
      			b_path = src+'/bundles/bundled_'+i
	      		if File.exists?(b_path)
	      			puts "Linking #{b_path}"
	      			ext = File.extname(b_path)
	      			case ext
	      			when ".js"
	      				markup.concat("<script type='text/javascript' src='/bundles/#{bundled_name}'></script>")
	      			when ".css"
	      				markup.concat("<link href='/bundles/#{bundled_name}' type='text/css' rel='stylesheet' />")
	      			else
	      				put "Invalid asset. #{b_path}"
	      			end
	      			
	      		else
	      			puts "#{i} not found."
	      		end
      		end
      		markup
      		
      	end

	end


end
Liquid::Template.register_tag('asset', Jekyll::AssetTag)