#!/usr/bin/env ruby

require 'mixlib/shellout'
require 'optparse'
require 'yaml'

class ChefRepo
  def initialize(conffile)
    File.open(conffile, 'r') do |f|
      @config = YAML.load(f.read())
    end
    
    globals = {
      'chefdir' => '/etc/chef',
      'repodir' => '/var/chef/repos',
      'keysdir' => '/var/chef/keys',
    }
    if @config['globals']
      globals.merge(@config['globals'])
    end
    @config['globals'] = globals
  end

  def get_config
    return @config
  end

  def get_key(name)
    key = @config['keys'][name]
    unless key
      return nil
    end  

    unless key['name']
      key['name'] = name
    end
    if key['path']
      File.open(key['path'], 'r') do |f|
        key['key'] = f.read()
      end
    else
      keysdir = @config['globals']['keysdir']
      unless File.directory?(keysdir)
        Dir.mkdir(keysdir, 0700)
      end
      key_path = "#{@config['globals']['keysdir']}/#{name}"
      unless File.exists?(key_path)
        File.open(key_path, 'w', 0600) do |f|
          f.write(key['key'])
        end
      end
      key['path'] = key_path
    end

    return key
  end

  def get_repo(name)
    repo = @config['repos'][name]
    unless repo['name']
      repo['name'] = name
    end
    unless repo['type']
      if repo['url'].include?('git')
        repo['type'] = 'git'
      else
        repo['type'] = 'hg'
      end
    end
    unless repo['path']
      repodir = @config['globals']['repodir']
      unless File.directory?(repodir)
        Dir.mkdir(repodir, 0755)
      end
      repo['path'] = File.join(repodir, repo['name'])
    end
    unless repo['key_path']
      key = repo['key'] ? get_key(repo['key']) : get_key(repo['name'])
      if key
        repo['key_path'] = key['path']
      end
    end
    
    return repo
  end

  def update_repo(name)
    repo = get_repo(name)
    sshcmd = repo['key_path'] ? "ssh -i #{repo['key_path']}" : ''
    sshopts = sshcmd ? "-e '#{sshcmd}'" : ''

    if File.directory?(repo['path'])
      case repo['type']
      when 'git'
        cmd = Mixlib::ShellOut.new(
          'git pull',
          :cwd => repo['path'],
          :environment => {
            'GIT_SSH' => sshcmd,
        })
        cmd.run_command
        cmd.error!
      when 'hg'
        cmd = Mixlib::ShellOut.new("hg pull #{sshopts} -u",
                                   :cwd => repo['path'])
        cmd.run_command
        cmd.error!
      else
        puts "Unsupported repo type: #{repo['type']}"
        exit 1
      end
    else
      case repo['type']
      when 'git'
        cmd = Mixlib::ShellOut.new(
          "git clone #{repo['url']} #{repo['path']}",
          :environment => {
            'GIT_SSH' => sshcmd,
        })
        cmd.run_command
        cmd.error!
      when 'hg'
        cmd = Mixlib::ShellOut.new(
          "hg clone #{sshopts} #{repo['url']} #{repo['path']}")
        cmd.run_command
        cmd.error!
      else
        puts "Unsupported repo type: #{repo['type']}"
        exit 1
      end
    end
  end
end

options = {
  'config' => '/etc/chef/repos.yml',
}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: chef-repo [options] <command>'
  opts.on('-c', '--config conffile', 'Config file') do |config|
    options['config'] = config
  end
  opts.on('-h', '--help', 'Displays help') do
    puts opts
    exit
  end
end

subcommands = [
  'get_repo',
  'get_key',
  'list_repos',
  'list_keys',
  'update_repo',
]

parser.parse!
command = ARGV.shift
unless command
  puts "You haven't told me what to do!"
  exit 1
end
unless subcommands.include?(command)
  puts "I don't know what this means"
  exit 1
end

chefrepo = ChefRepo.new(options['config'])

case command
when 'get_repo'
  repo = ARGV.shift
  puts chefrepo.get_repo(repo)
when 'get_key'
  key = ARGV.shift
  puts chefrepo.get_key(key)
when 'list_repos'
  puts chefrepo.get_config['repos'].keys
when 'list_keys'
  puts chefrepo.get_config['keys'].keys
when 'update_repo'
  repo = ARGV.shift
  puts chefrepo.update_repo(repo)
else
  puts "I don't know what to do"
  exit 1
end

exit 0
