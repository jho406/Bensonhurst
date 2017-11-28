require "webpacker/configuration"

babelrc = Rails.root.join(".babelrc")

def append_js_tags
  app_html = 'app/views/layouts/application.html.erb'
  js_tag = <<-JS_TAG

    <script type="text/javascript">
      window.BREEZY_INITIAL_PAGE_STATE=<%= breezy_snippet %>;
    </script>
  JS_TAG

  inject_into_file app_html, after: '<head>' do
    js_tag
  end

  inject_into_file app_html, after: '<body>' do
    "\n    <div id='app'></div>"
  end
end


if File.exist?(babelrc)
  react_babelrc = JSON.parse(File.read(babelrc))
  react_babelrc["presets"] ||= []
  react_babelrc["plugins"] ||= []

  if !react_babelrc["presets"].include?("react")
    react_babelrc["presets"].push("react")
    say "Copying react preset to your .babelrc file"

    File.open(babelrc, "w") do |f|
      f.puts JSON.pretty_generate(react_babelrc)
    end
  end

  if !react_babelrc["plugins"].any?{|plugin| Array(plugin).include?("module-resolver")}
    react_babelrc["plugins"].push(["module-resolver", {
      "root": ["./app"],
      "alias": {
        "views": "./app/views",
        "components": "./app/components",
        "javascripts": "./app/javascripts"
      }
    }])

    say "Copying module-resolver preset to your .babelrc file"

    File.open(babelrc, "w") do |f|
      f.puts JSON.pretty_generate(react_babelrc)
    end
  end

else
  say "Copying .babelrc to app root directory"
  copy_file "#{__dir__}/templates/web/.babelrc", ".babelrc"
end

say "Copying application.js file to #{Webpacker.config.source_entry_path}"
copy_file "#{__dir__}/templates/web/application.js", "#{Webpacker.config.source_entry_path}/application.js"

say "Appending js tags to your application.html.erb"
append_js_tags

say "Installing all breezy dependencies"
run "yarn add history react react-dom babel-preset-react prop-types --save"
run "yarn add babel-plugin-module-resolver --save-dev"
run "yarn add react-redux redux --save-dev"
run "yarn add @jho406/breezy"

say "Webpacker now supports breezy.js 🎉", :green
