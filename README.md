# chef-repoman
A tool to wrangle multiple Chef repositories

## Get started

Create a `repos.yml` configuration (by default in `/etc/chef/repos.yml`). Something like this:

```
repos:
  chef-cookbooks:
    url: https://github.com/facebook/chef-cookbooks.git
  
  cake-chef:
    url: ssh://hg@bitbucket.org/notarealrepo/cake-chef
    is_primary_repo: true
    
 pie-chef:
    url: ssh://git@github.com/notarealrepo/pie-chef
    key: cake-chef
    type: git
    
 not-a-chef-repo:
    url: ssh://hg@bitbucket.org/notarealrepo/super_secret_stuff
    key: dont-look-at-me
    path: /opt/secrets

keys:
  cake-chef:
    key: |
      -----BEGIN RSA PRIVATE KEY-----
      ...
      -----END RSA PRIVATE KEY-----
  dont-look-at-me:
    key_path: /etc/chef/super_secret_key
```

Then run `chef-repoman update` to lay down keys and fetch all the repos. If you need a stub `client.rb` to bootstrap Chef,
run `chef-repoman get_client_rb` -- it'll set the `role_path` to the primary repo and automatically ignore non-cookbooks 
repos you may have listed).
