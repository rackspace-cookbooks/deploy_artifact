require 'spec_helper'
require 'digest/md5'

describe file('/var/keep_releases/current') do
  it { should be_symlink }
end

describe file('/var/keep_releases/cached-copy/keep_releases.tar.gz') do
  it { should be_file }
end

cached_checksum = Digest::MD5.hexdigest(File.read('/var/keep_releases/cached-copy/keep_releases.tar.gz'))
describe file("/var/keep_releases/releases/#{cached_checksum}") do
  it { should be_directory }
end

describe command('tar --compare -f /var/keep_releases/cached-copy/keep_releases.tar.gz \
                 -C /var/keep_releases/current | grep -Ev \'Uid|Gid\'') do
  its(:stdout) { should match('') }
end
