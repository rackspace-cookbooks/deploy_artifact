require 'spec_helper'
require 'digest/md5'

describe file('/var/keep_releases/current') do
  it { should be_directory }
end

describe file('/var/keep_releases/cached-copy/keep_releases.tar.gz') do
  it { should be_file }
end

describe command('tar --compare -f /var/keep_releases/cached-copy/keep_releases.tar.gz \
                 -C /var/keep_releases/current') do
  its(:stdout) { should match('') }
  its(:exit_status) { should eq 0 }
end
