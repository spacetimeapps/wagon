require 'locomotive/common'

require_relative '../tools/styled_yaml'

require_relative 'loggers/pull_logger'

require_relative_all  'concerns'

require_relative      'pull_sub_commands/pull_base_command'
require_relative_all  'pull_sub_commands'

module Locomotive::Wagon

  class ImportCommand < Struct.new(:name, :source_path, :target_path, :options, :shell)

    RESOURCES = %w(site pages content_types content_entries snippets sections theme_assets translations content_assets).freeze

    include ApiConcern
    include DeployFileConcern
    include InstrumentationConcern
    include SpinnerConcern
    

    def self.import(name, source_path, target_path, options, shell)
      self.new(name, source_path, target_path, options, shell).import
    end

    def import
      _import
    end

    private

    def _import
      ImportSection.source_root(source_path)
      thor = ImportSection.new
        
      templates = Dir.glob(File.join(sections_path(source_path), "#{name}.liquid*"))
      if templates.size == 1
        filename = File.basename(templates.first)
        thor.copy_file(templates.first, File.join(sections_path(target_path), filename))
      else
        raise ImportException, "Section template not found"
      end

      javascript = Dir.glob(File.join(sections_js_path(source_path), "#{name}.js*"))
      if javascript.size == 1
        filename = File.basename(javascript.first)
        thor.copy_file(javascript.first, File.join(sections_js_path(target_path), filename))
      else
        raise ImportException, "Section js not found"
      end

      stylesheet = Dir.glob(File.join(sections_css_path(source_path), "#{name}.{c,sa,sc}ss*"))
      if stylesheet.size == 1
        filename = File.basename(stylesheet.first)
        thor.copy_file(stylesheet.first, File.join(sections_css_path(target_path), filename))

      else
        raise ImportException, "Section css not found"
      end

      
      js_class_name = name.classify
      export_string = "export { default as #{js_class_name} } from './#{name}';"
      index_file = File.join(sections_js_path(target_path), 'index.js')

      thor.append_to_file index_file , <<-JS
export { default as #{js_class_name} } from './#{name}';
          JS

      thor.insert_into_file File.join(target_path, 'app/assets/javascripts/app.js'), after: "// Register sections here. DO NOT REMOVE OR UPDATE THIS LINE\n" do
        "  sectionsManager.registerSection('#{name}', Sections.#{js_class_name});\n"
      end

      thor.insert_into_file File.join(target_path,'app/assets/stylesheets/app.scss'), after: "// Register sections here. DO NOT REMOVE OR UPDATE THIS LINE\n" do
        "@import 'sections/#{name}';\n"
      end

      print_result_message
    end

    def each_resource
      RESOURCES.each do |name|
        next if !options[:resources].blank? && !options[:resources].include?(name)

        klass = "Locomotive::Wagon::Pull#{name.camelcase}Command".constantize

        yield klass
      end
    end

    def connection_information
      read_deploy_settings(self.env, self.path)
    end

    def print_result_message
      shell.try(:say, "\n\nThe section has been imported from the selected project.", :green)
      true
    end
    
    class ImportException < Exception
    end
    
    class ImportSection
      include Thor::Base
      include Thor::Actions
    end
    
    protected

    def sections_path(path)
      File.join(path, 'app', 'views', 'sections')
    end

    def sections_js_path(path)
      File.join(path, 'app', 'assets', 'javascripts', 'sections')
    end

    def sections_css_path(path)
      File.join(path, 'app', 'assets', 'stylesheets', 'sections')
    end
    

  end

end
