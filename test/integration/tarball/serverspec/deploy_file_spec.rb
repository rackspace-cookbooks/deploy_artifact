require 'spec_helper'
require 'digest/md5'

describe 'shared tests' do
  it_behaves_like 'deployed_files'
end

describe file('/var/deploy_file/cached-copy/deploy_file.tar.gz') do
  it { should be_file }
end

cached_checksum = Digest::MD5.hexdigest(File.read('/var/deploy_file/cached-copy/deploy_file.tar.gz'))
describe file("/var/deploy_file/releases/#{cached_checksum}") do
  it { should be_directory }
end

describe command("tar --compare -f /var/deploy_file/cached-copy/deploy_file.tar.gz \
                 -C /var/deploy_file/releases/#{cached_checksum}") do
  its(:stdout) { should match('') }
  its(:exit_status) { should eq 0 }
end
