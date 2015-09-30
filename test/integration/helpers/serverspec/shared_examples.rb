shared_examples_for 'deployed_files' do
  # directory structure
  %w(
    /var/www
    /var/www/cached-copy
    /var/www/releases
  ). each do |dir|
    describe file(dir) do
      it { should be_directory }
    end
  end
end
