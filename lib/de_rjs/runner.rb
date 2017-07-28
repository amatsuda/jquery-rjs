require 'de_rjs'

module DeRjs
  class Runner
    attr_reader :filenames

    def initialize(filenames)
      @filenames = filenames
    end

    def execute
      filenames.each do |filename|
        source = File.read filename
        js_erb = rewrite_to_js_erb(source)
        File.open(filename, "w") {|f| f << js_erb}
      end
    end

    protected
    def rewrite_to_js_erb(rjs)
      rewritten_source = DeRjs::Rewriter.rewrite_rjs(rjs)
      generator = DeRjs::JqueryGenerator.new(nil) { eval(rewritten_source)}
      generator.to_s
    end
  end
end
