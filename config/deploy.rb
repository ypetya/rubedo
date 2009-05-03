set :application,   "rubedo"
set :repository,    "git://github.com/#{ENV['USER']}/rubedo.git"
set :scm,           :git

set :user,          "appuser"
set :keep_releases, 3
set :deploy_to,     "/srv/apps/#{application}"

set :domain,        ENV['MY_SERVER']

role :app, domain
role :web, domain
role :db,  domain, :primary => true

namespace :at_server do
  desc 'Copy the config files to the app'
  task :copy_the_config_files do
    run "cp -r /srv/config/#{application}/* #{release_path}"
  end
  after 'deploy:finalize_update','at_server:copy_the_config_files'

  desc 'Create neccessary directories for passenger and link shared things, like db'
  task :create_and_link_directories do
    # make dirs
    %w{public tmp}.each do |dir|
      run "mkdir -p #{release_path}/#{dir}"
    end
    # link dirs
    %w{db music}.each do |dir|
      run "ln #{deploy_to}/shared/#{dir} #{release_path}/#{dir} -s"
    end
  end
  after 'deploy:update_code','at_server:create_and_link_directories'
end

namespace :deploy do
  %w(start restart).each do |action|
    desc "Let Phusion Passenger #{action} the processes"
    task action.to_sym, :roles => :app do
      passenger.restart
    end
  end

  desc "Stop task is a no-op with Phusion Passenger"
  task :stop, :roles => :app do ; end
end

namespace :passenger do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end
