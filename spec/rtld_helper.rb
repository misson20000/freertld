require "bundler/setup"
require "lakebed"
require "lakebed/helpers"

module RtldHelpers
  def rtld
    @rtld||= File.open("rtld/rtld-by-buildid/#{ENV["RTLD"]}") do |f|
      Lakebed::Nso.from_file(f)
    end
  end
end

RSpec::configure do |c|
  Lakebed::configure c
  c.include RtldHelpers
end
