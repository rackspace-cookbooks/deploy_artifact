require 'spec_helper'
require 'digest/md5'

describe 'shared tests' do
  it_behaves_like 'deployed_files'
end

describe file('/var/www/cached-copy/latest.tar.gz') do
  it { should be_file }
end

cached_checksum = Digest::MD5.hexdigest(File.read('/var/www/cached-copy/latest.tar.gz'))
describe file("/var/www/releases/#{cached_checksum}") do
  it { should be_directory }
end

describe command("tar --compare -f /var/www/cached-copy/latest.tar.gz -C /var/www/releases/#{cached_checksum}") do
  its(:stdout) { should match('') }
  its(:exit_status) { should eq 0 }
end
