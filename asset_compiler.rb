#
# Jekyll Asset Compiler
#
# Author : Rohit Rox
# Repo   : http://github.com/rohitrox/jekyll-asset_compiler
# License: MIT, see LICENSE file
#
require 'yaml'
require 'net/http'
require 'uri'
require "yui/compressor"

module Jekyll

	class AssetGen < Generator
		safe true
		@@bundle_ext = ['.js', '.css']
		@@bundle_file_hash = {}
		@@state = true
		
		def self.bundle_file_hash
			@@bundle_file_hash
		end

		def self.state
			@@state
		end

		def self.bundle_ext
			@@bundle_ext
		end
		def self.state=(state)
			@@state = state
		end
		
		def generate(site)
			@files = {}
			@site = site
			bundle = false
			@src = site.source
			bundle_dir = @src + '/_bundles'
			puts "Asset Bundler"

				if Dir.glob(bundle_dir).empty?

					puts "Bundle directory not created , creating one ... "
					FileUtils.mkdir_p(bundle_dir)
					puts "Add your css and js bundle files here. See doc."

				elsif Dir.glob(bundle_dir + '/*').empty?
					puts "No Bundle files found ... "
				
				else
					puts "Found "+Dir.glob(bundle_dir + '/*').size.to_s+" bundle file(s)"
					bundle = true
				end

			if bundle
				process_file( Dir.glob(bundle_dir + '/*'))
			else
				@@state = false
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
		     
		    @@bundle_file_hash.merge!(bundles)
			bundles.each do |k,v|
				f_path = @site.source+'/_bundles/'+k.to_s	
				@site.static_files << AssetFileGen.new(@site, f_path)
			end

		end # end of load_files


	end # end of AssetGen class

	class AssetTag < Liquid::Block

		def initialize(tag_name, text, tokens)
      		super    
    	end

		def render(context)
      		src = context.registers[:site].source
      		includes = nodelist[0].split(',').map{|n| n.gsub(' ','')}
      		markup = ""
      		if AssetGen.state
	      		includes.each do |i|
	      			bundled_name = i
	      			b_path = src+'/bundles/'+i
	      			
		      			ext = File.extname(b_path)
		      			case ext
		      			when ".js"
		      				markup.concat("<script type='text/javascript' src='/bundles/#{bundled_name}'></script>")
		      			when ".css"
		      				markup.concat("<link href='/bundles/#{bundled_name}' type='text/css' rel='stylesheet' />")
		      			end		      			

	      		end
	      		markup
	      	end
      		
      	end

	end


	class AssetFileGen < StaticFile

		def initialize(site, file)
			super(site, site.source, File.dirname(file), File.basename(file))
			@src = site.source
		end

		def write(dest)
			AssetGen.bundle_file_hash.each do |k, v|

				f_ext = File.extname(k)

				if f_ext == ".js"
					current_ext = ".js"
					compressor = YUI::JavaScriptCompressor.new
				elsif f_ext == '.css'
					current_ext = ".css"
					compressor = YUI::CssCompressor.new
				end

				file_arr = v.split(' ')
		
				f_ext_coll = file_arr.map{ |f| File.extname(f) }
				if f_ext_coll.uniq.length > 1 && current_ext == f_ext_coll.uniq[0]
					puts "Aborting. There is js and css mixmax in #{k}. Please fix it first. "
					AssetGen.state = false
				elsif AssetGen.bundle_ext.include?(f_ext_coll.uniq[0])
					compressed = ""
					file_arr.each do |f|
		
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
											AssetGen.state = false
											return
										end
									end
									begin
									compressed_content = compressor.compress(content)
									compressed = compressed.concat(compressed_content)
									FileUtils.mkdir_p(dest + '/bundles')
									File.open(dest+'/bundles/'+k,'w'){ |f| f.write(compressed)}
									rescue
										puts "compression failed for #{f} ..."
										AssetGen.state = false
										return
									end
									
									
									
					end
				else
					puts "Aborting. Unsupported file in #{k} bundle list. Please fix it first"
					AssetGen.state = false
					return
				end

			end

			true
		end

	end


end
Liquid::Template.register_tag('asset', Jekyll::AssetTag)