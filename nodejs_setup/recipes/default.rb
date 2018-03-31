app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

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

application app_path do
  javascript "4"
  environment.update("PORT" => "80")
  environment.update(app["environment"])

  tmpdir = Dir.mktmpdir("opsworks")
  directory tmpdir do
    owner 'ec2-user'
    group 'ec2-user'
    mode 0755
  end

  aws_s3_file "#{tmpdir}/archive" do
    bucket s3_bucket
    remote_path s3_remote_path
    retries 3
  end

  file "#{tmpdir}/archive" do
    mode '0755'
  end

  bash 'extract_code_zip' do
    cwd app["app_path"]
    code "sudo unzip #{tmpdir}/archive"
  end

  # zipfile "#{tmpdir}/archive" do
  #   into "#{app_path}"
  #   overwrite true
  # end

  link "#{app_path}/server.js" do
    to "#{app_path}/index.js"
  end

  npm_install
  npm_start do
    action [:stop, :enable, :start]
  end
end
