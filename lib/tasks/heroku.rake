namespace :heroku do
    desc "Compile AOT frontend"
    task :compile => :config do
        Dir.chdir("angular-web") do
            system("ng build --aot")
        end
    end

    desc "Write config"
    task :config do
        config = <<EOF
export class AppSettings {
   public static API_ENDPOINT = '#{ENV["HEROKU_URL"]}';
}
EOF
        File.open("angular-web/src/app/app.settings.ts", "w+") do |f|
            f.write(config)
        end
    end
end
