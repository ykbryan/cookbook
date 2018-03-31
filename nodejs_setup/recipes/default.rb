app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

directory "#{app_path}" do
  owner 'root'
  group 'root'
  mode '0777'
  recursive true
  action :create
end

directory "#{app_path}/node_modules" do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end

uri = URI.parse(app["app_source"]["url"])
uri_path_components = uri.path.split("/").reject{ |p| p.empty? }
virtual_host_match = uri.host.match(/\A(.+)\.s3(?:[-.](?:ap|eu|sa|us)-(?:.+-)\d|-external-1)?\.amazonaws\.com/i)
s3_base_uri = uri.dup

if virtual_host_match
  s3_bucket = virtual_host_match[1]
  s3_base_uri.path = "/"
else
  s3_bucket = uri_path_components[0]
  s3_base_uri.path = "/#{uri_path_components.shift}"
end

s3_remote_path = uri_path_components.join("/")
s3_base_uri.to_s.chomp!("/")

# package "git" do
#   # workaround for:
#   # WARNING: The following packages cannot be authenticated!
#   # liberror-perl
#   # STDERR: E: There are problems and -y was used without --force-yes
#   options "--force-yes" if node["platform"] == "ubuntu" && node["platform_version"] == "14.04"
# end

tmpdir = Dir.mktmpdir("opsworks")
directory tmpdir do
  owner 'ec2-user'
  group 'ec2-user'
  mode 0755
end

s3_file "#{tmpdir}/archive" do
  bucket s3_bucket
  remote_path s3_remote_path
end

file "#{tmpdir}/archive" do
  mode '0755'
end

execute 'extract_code' do
  cwd "#{app_path}"
  retries 1
  command "cd #{app_path} && sudo unzip -o #{tmpdir}/archive"
  # command "unzip -o #{tmpdir}/archive"
end

application "#{app_path}" do
  javascript "4"
  environment.update("PORT" => "80")
  environment.update(app["environment"])

  # git app_path do
  #   repository app["app_source"]["url"]
  #   revision app["app_source"]["revision"]
  # end

  # link "#{app_path}/server.js" do
  #   to "#{app_path}/index.js"
  # end

  # npm_install do
  #   retries 3
  #   retry_delay 10
  # end

  npm_start do
    action [:stop, :enable, :start, :restart]
  end
end
