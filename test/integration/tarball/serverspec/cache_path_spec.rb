require 'spec_helper'
require 'digest/md5'

describe 'shared tests' do
  it_behaves_like 'deployed_files'
end

describe file('/tmp/cache_path.tar.gz') do
  it { should be_file }
end

cached_checksum = Digest::MD5.hexdigest(File.read('/tmp/cache_path.tar.gz'))
describe file("/var/cache_path/releases/#{cached_checksum}") do
  it { should be_directory }
end

describe command("tar --compare -f /tmp/cache_path.tar.gz \
                 -C /var/cache_path/releases/#{cached_checksum}") do
  its(:stdout) { should match('') }
  its(:exit_status) { should eq 0 }
end
