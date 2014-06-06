namespace :drush do
  # Initializes drush directory and aliases
  task :initialize do
    invoke 'drush:drushdir'
    invoke 'drush:aliases'
  end

  # Creates ~/.drush directory if it's missing
  task :drushdir do
    on roles(:all) do
      home = capture(:echo, '$HOME') 
      unless test "[ -d #{home}/.drush ]"
        execute :mkdir, "#{home}/.drush"
      end
    end
  end

  # Copies any aliases from the root checkout to the logged in user's ~/.drush directory
  task :aliases do
    on roles(:all) do
      within "#{release_path}" do
        home = capture(:echo, '$HOME')
        execute :cp, "*.aliases.drushrc.php", "#{home}/.drush", "|| :"
      end
    end
  end

  # Triggers drush sql-sync to copy databases between environments
  task :sqlsync do 
    on roles(:app) do
      if ENV['source']
        within "#{release_path}/public" do
          execute :drush, "-p -r #{current_path}/public -l #{fetch(:site_url)[0]} sql-sync #{ENV['source']} @self -y"
        end
      end
    end

    invoke 'drush:run_updates'
  end

  # Triggers drush rsync to copy files between environments
  task :rsync do
    on roles(:app) do
      if ENV['path']
        path = ENV['path']
      else
        path = '%files'
      end

      if ENV['source']
        within "#{release_path}/public" do
          execute :drush, "-y -p -r #{current_path}/public -l #{fetch(:site_url)[0]} rsync #{ENV['source']}:#{path} @self:#{path} --mode=rz"
        end
      end
    end
  end

  # Creates database backup
  task :dbbackup do 
    on roles(:app) do
      unless test " [ -f #{release_path}/db.sql ]"
        within "#{release_path}/public" do
          execute :drush, "-p -r #{current_path}/public -l #{fetch(:site_url)[0]} sql-dump -y >> #{release_path}/db.sql"
        end
      end
    end
  end
  
  # Runs all pending update hooks
  task :updatedb do
    on roles(:app) do
      within "#{release_path}/public" do
        fetch(:site_url).each do |site|
          execute :drush, "-y -p -r #{current_path}/public -l #{site}", 'updatedb'
        end
      end
    end
  end

  task :cache_clear do
    on roles(:app) do
      within "#{release_path}/public" do
        fetch(:site_url).each do |site|
          execute :drush, "-y -p -r #{current_path}/public -l #{site}", 'cc all'
        end
      end
    end
  end

  task :run_updates do
    invoke 'drush:updatedb'
    invoke 'drush:cache_clear'
    invoke 'drush:features:revert'
    invoke 'drush:cache_clear'
  end
  
  namespace :features do
    task :revert do
      on roles(:app) do
        within "#{release_path}/public" do
          fetch(:site_url).each do |site|
            execute :drush, "-y -p -r #{current_path}/public -l #{site}", 'fra'
          end
        end
      end
    end
  end
end
