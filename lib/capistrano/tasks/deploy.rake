Rake::Task['deploy:cleanup'].clear
Rake::Task['deploy:cleanup_rollback'].clear

namespace :deploy do
  namespace :restarting do
    task :varnish do
      on roles(:web) do
        if test " [ -r /etc/varnish/secret ]"
          fetch(:site_url).each do |site|
            execute :varnishadm, "'ban req.http.host ~ #{site}'"
          end
        end
      end
    end
  end
  
  task :restart do
    invoke 'deploy:restarting:varnish'
  end
  
  namespace :symlink do
    task :drupal do
      on roles(:app) do
        execute :rm, '-rf', deploy_to + "/#{fetch(:webroot)}"
        execute :ln, '-s', "#{current_path}/public", deploy_to + "/#{fetch(:webroot)}"
      end
    end

    task :settings do
      on roles(:app) do
        fetch(:site_folder).each do |folder|
          unless test " [ -f #{current_path}/public/sites/#{folder}/settings.php ]"
            execute :ln, '-s', "#{current_path}/public/sites/#{folder}/settings.#{fetch(:stage)}.php", "#{current_path}/public/sites/#{folder}/settings.php"
          end
        end
        
        unless test " [ -f #{current_path}/public/.htaccess ]"
          execute :ln, '-s', "#{current_path}/public/htaccess.#{fetch(:stage)}", "#{current_path}/public/.htaccess"
        end

        unless test " [ -f #{current_path}/public/robots.txt ]"
          execute :ln, '-s', "#{current_path}/public/robots.#{fetch(:stage)}.txt", "#{current_path}/public/robots.txt"
        end
      end
    end
  end
  
  task :revert_database => :rollback_release_path do
    on roles(:db) do
      within "#{release_path}/public" do
      	execute :drush, "-y sql-drop -l #{fetch(:site_url)} &&", %{$(drush sql-connect -l #{fetch(:site_url)}) < #{release_path}/db.sql}
      end
    end
  end
  
  desc 'Clean up old releases'
  task :cleanup do
    on roles :all do |host|
      releases = capture(:ls, '-x', releases_path).split
      if releases.count >= fetch(:keep_releases)
        info t(:keeping_releases, host: host.to_s, keep_releases: fetch(:keep_releases), releases: releases.count)
        directories = (releases - releases.last(fetch(:keep_releases)))
        if directories.any?
          directories_str = directories.map do |release|
            releases_path.join(release)
          end.join(" ")
          execute :chmod, '-R', 'u+rw', directories_str
          execute :rm, '-rf', directories_str
        else
          info t(:no_old_releases, host: host.to_s, keep_releases: fetch(:keep_releases))
        end
      end
    end
  end
  
  desc 'Remove and archive rolled-back release.'
  task :cleanup_rollback do
    on roles(:all) do
      last_release = capture(:ls, '-xr', releases_path).split.first
      last_release_path = releases_path.join(last_release)
      if test "[ `readlink #{current_path}` != #{last_release_path} ]"
        execute :tar, '-czf',
          deploy_path.join("rolled-back-release-#{last_release}.tar.gz"),
        last_release_path
        execute :chmod, '-R', 'u+rw', last_release_path
        execute :rm, '-rf', last_release_path
      else
        debug 'Last release is the current release, skip cleanup_rollback.'
      end
    end
  end
end
