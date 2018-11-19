require "bundler/setup"
require "lakebed"
require "lakebed/helpers"

module RtldHelpers
  def rtld
    if !Dir.exist?("rtld") then
      Dir.mkdir("rtld")
    end
    if !Dir.exist?("rtld/rtld-by-buildid") then
      Dir.mkdir("rtld/rtld-by-buildid")
    end
    if !File.exist?("rtld/rtld-by-buildid/#{ENV["RTLD"]}") then
      if ENV["B2_ACCOUNT_ID"] && ENV["B2_APPLICATION_KEY"] then
        puts "downloading #{ENV["RTLD"]} from b2..."
        require "fog/backblaze"
        @connection||= Fog::Storage.new(:provider => "backblaze", :b2_key_id => ENV["B2_ACCOUNT_ID"], :b2_key_token => ENV["B2_APPLICATION_KEY"], :b2_bucket_name => "freertld")
        File.write("rtld/rtld-by-buildid/#{ENV["RTLD"]}", @connection.get_object("freertld", "rtld/#{ENV["RTLD"]}").body)
        puts "downloaded #{ENV["RTLD"]} from b2"
      end
    end
    @rtld||= File.open("rtld/rtld-by-buildid/#{ENV["RTLD"]}") do |f|
      Lakebed::Nso.from_file(f)
    end
  end
end

RSpec::configure do |c|
  Lakebed::configure c
  c.include RtldHelpers
end
