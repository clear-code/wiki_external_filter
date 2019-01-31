require_relative "wiki_external_filter/version"
require_dependency "wiki_external_filter/filter"
require_dependency "wiki_external_filter/renderer"

Rails.logger.info 'Starting wiki_external_filter plugin for Redmine'

Redmine::Plugin.register :wiki_external_filter do
  name 'Wiki External Filter plugin'
  author 'Kouhei Sutou, Alexander Tsvyashchenko (the original author)'
  description 'Processes given text using external command and renders its output'
  author_url 'https://github.com/clear-code/redmine_wiki_external_filter'
  version WikiExternalFilter::VERSION
  requires_redmine :version_or_higher => '3.4.0'

  settings :default => {'cache_seconds' => '60'}, :partial => 'wiki_external_filter/settings'

  config = WikiExternalFilter::Filter.config
  Rails.logger.debug "Config: #{config.inspect}"

  config.keys.each do |name|
    Rails.logger.info "Registering #{name} macro with wiki_external_filter"
    Redmine::WikiFormatting::Macros.register do
      info = config[name]
      desc info['description']
      macro name do |obj, args, text|
        m = WikiExternalFilter::Renderer.new(self, args, text, obj.respond_to?('page') ? obj.page.attachments : nil, name, info)
        m.render
      end
      # code borrowed from wiki latex plugin
      # code borrowed from wiki template macro
      desc info['description']
      macro (name + "_include").to_sym do |obj, args, text|
        page = Wiki.find_page(args.to_s, :project => @project)
        raise 'Page not found' if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)
        @included_wiki_pages ||= []
        raise 'Circular inclusion detected' if @included_wiki_pages.include?(page.title)
        @included_wiki_pages << page.title
        m = WikiExternalFilter::Renderer.new(self, args, page.content.text, page.attachments, name, info)
        @included_wiki_pages.pop
        m.render_block(args.to_s)
      end
    end
  end
end

