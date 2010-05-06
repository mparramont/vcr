$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'vcr'

begin
  require 'ruby-debug'
  Debugger.start
  Debugger.settings[:autoeval] = true if Debugger.respond_to?(:settings)
rescue LoadError
  # ruby-debug wasn't available so neither can the debugging be
end

require 'spec/expectations'

VCR.config do |c|
  c.cassette_library_dir = File.join(File.dirname(__FILE__), '..', 'fixtures', 'vcr_cassettes', RUBY_VERSION)
  c.http_stubbing_library = if ENV['HTTP_STUBBING_ADAPTER'].to_s == ''
    warn "Using fakeweb for VCR's cucumber features since the adapter was not specified.  Set HTTP_STUBBING_ADAPTER to specify."
    :fakeweb
  else
    ENV['HTTP_STUBBING_ADAPTER'].to_sym
  end
end

VCR.module_eval do
  def self.completed_cucumber_scenarios
    @completed_cucumber_scenarios ||= []
  end

  class << self
    attr_accessor :current_cucumber_scenario
  end
end

After do |scenario|
  if raised_error = (@http_requests || {}).values.flatten.detect { |result| result.is_a?(Exception) && result.message !~ /VCR/ }
    raise raised_error
  end
  VCR.completed_cucumber_scenarios << scenario
end

Before do |scenario|
  VCR.current_cucumber_scenario = scenario
  temp_dir = File.join(VCR::Config.cassette_library_dir, 'temp')
  FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
end

Before('@copy_not_the_real_response_to_temp') do
  orig_file = File.join(VCR::Config.cassette_library_dir, 'not_the_real_response.yml')
  temp_file = File.join(VCR::Config.cassette_library_dir, 'temp', 'not_the_real_response.yml')
  FileUtils.mkdir_p(File.join(VCR::Config.cassette_library_dir, 'temp'))
  FileUtils.cp orig_file, temp_file
end

at_exit do
  %w(record_cassette1 record_cassette2).each do |tag|
    file = File.join(VCR::Config.cassette_library_dir, 'cucumber_tags', "#{tag}.yml")
    FileUtils.rm_rf(file) if File.exist?(file)
  end
end

VCR.cucumber_tags do |t|
  t.tags '@record_cassette1', '@record_cassette2', :record => :new_episodes
  t.tags '@replay_cassette1', '@replay_cassette2', '@replay_cassette3', :record => :none
end