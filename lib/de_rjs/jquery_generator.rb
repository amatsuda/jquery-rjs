unless defined? JQUERY_VAR
  JQUERY_VAR = 'jQuery'
end

module DeRjs
  # A string that returns itself as its JSON-encoded form.
  class JsonLiteral < String
    def as_json(options = nil) self end #:nodoc:
    def encode_json(encoder) self end #:nodoc:
  end

  class JqueryGenerator #:nodoc:
    class OutputBuffer < Array
      def encoding
        Encoding::UTF_8
      end
    end
    def initialize(context, &block) #:nodoc:
      @context, @lines = context, OutputBuffer.new
      include_helpers_from_context
      #@context.with_output_buffer(@lines) do
      #@context.instance_exec(self, &block)
      #end
      self.instance_exec(&block)
    end

    private
    def include_helpers_from_context
      #extend @context.helpers if @context.respond_to?(:helpers) && @context.helpers
      extend GeneratorMethods
    end

    # JavaScriptGenerator generates blocks of JavaScript code that allow you
    # to change the content and presentation of multiple DOM elements.  Use
    # this in your Ajax response bodies, either in a <tt>\<script></tt> tag
    # or as plain JavaScript sent with a Content-type of "text/javascript".
    #
    # Create new instances with PrototypeHelper#update_page or with
    # ActionController::Base#render, then call +insert_html+, +replace_html+,
    # +remove+, +show+, +hide+, +visual_effect+, or any other of the built-in
    # methods on the yielded generator in any order you like to modify the
    # content and appearance of the current page.
    #
    # Example:
    #
    #   # Generates:
    #   #     new Element.insert("list", { bottom: "<li>Some item</li>" });
    #   #     new Effect.Highlight("list");
    #   #     ["status-indicator", "cancel-link"].each(Element.hide);
    #   update_page do |page|
    #     page.insert_html :bottom, 'list', "<li>#{@item.name}</li>"
    #     page.visual_effect :highlight, 'list'
    #     page.hide 'status-indicator', 'cancel-link'
    #   end
    #
    #
    # Helper methods can be used in conjunction with JavaScriptGenerator.
    # When a helper method is called inside an update block on the +page+
    # object, that method will also have access to a +page+ object.
    #
    # Example:
    #
    #   module ApplicationHelper
    #     def update_time
    #       page.replace_html 'time', Time.now.to_s(:db)
    #       page.visual_effect :highlight, 'time'
    #     end
    #   end
    #
    #   # Controller action
    #   def poll
    #     render(:update) { |page| page.update_time }
    #   end
    #
    # Calls to JavaScriptGenerator not matching a helper method below
    # generate a proxy to the JavaScript Class named by the method called.
    #
    # Examples:
    #
    #   # Generates:
    #   #     Foo.init();
    #   update_page do |page|
    #     page.foo.init
    #   end
    #
    #   # Generates:
    #   #     Event.observe('one', 'click', function () {
    #   #       $('two').show();
    #   #     });
    #   update_page do |page|
    #     page.event.observe('one', 'click') do |p|
    #      p[:two].show
    #     end
    #   end
    #
    # You can also use PrototypeHelper#update_page_tag instead of
    # PrototypeHelper#update_page to wrap the generated JavaScript in a
    # <tt>\<script></tt> tag.
    module GeneratorMethods
      def to_s #:nodoc:
        #(@lines * $/).tap do |javascript|
          #if ActionView::Base.debug_rjs
            #source = javascript.dup
            #javascript.replace "try {\n#{source}\n} catch (e) "
            #javascript << "{ alert('RJS error:\\n\\n' + e.toString()); alert('#{source.gsub('\\','\0\0').gsub(/\r\n|\n|\r/, "\\n").gsub(/["']/) { |m| "\\#{m}" }}'); throw e }"
          #end
        #end

        @lines * $/
      end

      def jquery_id(id) #:nodoc:
        id.sub(/<%=.*%>/,'').to_s.count('#.*,>+~:[/ ') == 0 ? "##{id}" : id
      end

      def jquery_ids(ids) #:nodoc:
        Array(ids).map{|id| jquery_id(id)}.join(',')
      end

      # Returns a element reference by finding it through +id+ in the DOM. This element can then be
      # used for further method calls. Examples:
      #
      #   page['blank_slate']                  # => $('blank_slate');
      #   page['blank_slate'].show             # => $('blank_slate').show();
      #   page['blank_slate'].show('first').up # => $('blank_slate').show('first').up();
      #
      # You can also pass in a record, which will use ActionController::RecordIdentifier.dom_id to lookup
      # the correct id:
      #
      #   page[@post]     # => $('post_45')
      #   page[Post.new]  # => $('new_post')
      def [](id)
        case id
        when String, Symbol, NilClass
          JavaScriptElementProxy.new(self, id)
        else
          JavaScriptElementProxy.new(self, ActionController::RecordIdentifier.dom_id(id))
        end
      end

      # Returns an object whose <tt>to_json</tt> evaluates to +code+. Use this to pass a literal JavaScript
      # expression as an argument to another JavaScriptGenerator method.
      def literal(code)
        JsonLiteral.new(code.to_s)
      end

      # Returns a collection reference by finding it through a CSS +pattern+ in the DOM. This collection can then be
      # used for further method calls. Examples:
      #
      #   page.select('p')                      # => $$('p');
      #   page.select('p.welcome b').first      # => $$('p.welcome b').first();
      #   page.select('p.welcome b').first.hide # => $$('p.welcome b').first().hide();
      #
      # You can also use prototype enumerations with the collection.  Observe:
      #
      #   # Generates: $$('#items li').each(function(value) { value.hide(); });
      #   page.select('#items li').each do |value|
      #     value.hide
      #   end
      #
      # Though you can call the block param anything you want, they are always rendered in the
      # javascript as 'value, index.'  Other enumerations, like collect() return the last statement:
      #
      #   # Generates: var hidden = $$('#items li').collect(function(value, index) { return value.hide(); });
      #   page.select('#items li').collect('hidden') do |item|
      #     item.hide
      #   end
      #
      def select(pattern)
        JavaScriptElementCollectionProxy.new(self, pattern)
      end

      # Inserts HTML at the specified +position+ relative to the DOM element
      # identified by the given +id+.
      #
      # +position+ may be one of:
      #
      # <tt>:top</tt>::    HTML is inserted inside the element, before the
      #                    element's existing content.
      # <tt>:bottom</tt>:: HTML is inserted inside the element, after the
      #                    element's existing content.
      # <tt>:before</tt>:: HTML is inserted immediately preceding the element.
      # <tt>:after</tt>::  HTML is inserted immediately following the element.
      #
      # +options_for_render+ may be either a string of HTML to insert, or a hash
      # of options to be passed to ActionView::Base#render.  For example:
      #
      #   # Insert the rendered 'navigation' partial just before the DOM
      #   # element with ID 'content'.
      #   # Generates: Element.insert("content", { before: "-- Contents of 'navigation' partial --" });
      #   page.insert_html :before, 'content', :partial => 'navigation'
      #
      #   # Add a list item to the bottom of the <ul> with ID 'list'.
      #   # Generates: Element.insert("list", { bottom: "<li>Last item</li>" });
      #   page.insert_html :bottom, 'list', '<li>Last item</li>'
      #
      def insert_html(position, id, *options_for_render)
        insertion = position.to_s.downcase
        insertion = 'append' if insertion == 'bottom'
        insertion = 'prepend' if insertion == 'top'
        call "#{JQUERY_VAR}(\"#{jquery_id(id)}\").#{insertion}", render(*options_for_render)
        # content = javascript_object_for(render(*options_for_render))
        # record "Element.insert(\"#{id}\", { #{position.to_s.downcase}: #{content} });"
      end

      # Replaces the inner HTML of the DOM element with the given +id+.
      #
      # +options_for_render+ may be either a string of HTML to insert, or a hash
      # of options to be passed to ActionView::Base#render.  For example:
      #
      #   # Replace the HTML of the DOM element having ID 'person-45' with the
      #   # 'person' partial for the appropriate object.
      #   # Generates:  Element.update("person-45", "-- Contents of 'person' partial --");
      #   page.replace_html 'person-45', :partial => 'person', :object => @person
      #
      def replace_html(id, *options_for_render)
        call "#{JQUERY_VAR}(\"#{jquery_id(id)}\").html", render(*options_for_render)
        # call 'Element.update', id, render(*options_for_render)
      end

      # Replaces the "outer HTML" (i.e., the entire element, not just its
      # contents) of the DOM element with the given +id+.
      #
      # +options_for_render+ may be either a string of HTML to insert, or a hash
      # of options to be passed to ActionView::Base#render.  For example:
      #
      #   # Replace the DOM element having ID 'person-45' with the
      #   # 'person' partial for the appropriate object.
      #   page.replace 'person-45', :partial => 'person', :object => @person
      #
      # This allows the same partial that is used for the +insert_html+ to
      # be also used for the input to +replace+ without resorting to
      # the use of wrapper elements.
      #
      # Examples:
      #
      #   <div id="people">
      #     <%= render :partial => 'person', :collection => @people %>
      #   </div>
      #
      #   # Insert a new person
      #   #
      #   # Generates: new Insertion.Bottom({object: "Matz", partial: "person"}, "");
      #   page.insert_html :bottom, :partial => 'person', :object => @person
      #
      #   # Replace an existing person
      #
      #   # Generates: Element.replace("person_45", "-- Contents of partial --");
      #   page.replace 'person_45', :partial => 'person', :object => @person
      #
      def replace(id, *options_for_render)
        call "#{JQUERY_VAR}(\"#{jquery_id(id)}\").replaceWith", render(*options_for_render)
        #call 'Element.replace', id, render(*options_for_render)
      end

      # Removes the DOM elements with the given +ids+ from the page.
      #
      # Example:
      #
      #  # Remove a few people
      #  # Generates: ["person_23", "person_9", "person_2"].each(Element.remove);
      #  page.remove 'person_23', 'person_9', 'person_2'
      #
      def remove(*ids)
        call "#{JQUERY_VAR}(\"#{jquery_ids(ids)}\").remove"
        #loop_on_multiple_args 'Element.remove', ids
      end

      # Shows hidden DOM elements with the given +ids+.
      #
      # Example:
      #
      #  # Show a few people
      #  # Generates: ["person_6", "person_13", "person_223"].each(Element.show);
      #  page.show 'person_6', 'person_13', 'person_223'
      #
      def show(*ids)
        call "#{JQUERY_VAR}(\"#{jquery_ids(ids)}\").show"
        #loop_on_multiple_args 'Element.show', ids
      end

      # Hides the visible DOM elements with the given +ids+.
      #
      # Example:
      #
      #  # Hide a few people
      #  # Generates: ["person_29", "person_9", "person_0"].each(Element.hide);
      #  page.hide 'person_29', 'person_9', 'person_0'
      #
      def hide(*ids)
        call "#{JQUERY_VAR}(\"#{jquery_ids(ids)}\").hide"
        #loop_on_multiple_args 'Element.hide', ids
      end

      # Toggles the visibility of the DOM elements with the given +ids+.
      # Example:
      #
      #  # Show a few people
      #  # Generates: ["person_14", "person_12", "person_23"].each(Element.toggle);
      #  page.toggle 'person_14', 'person_12', 'person_23'      # Hides the elements
      #  page.toggle 'person_14', 'person_12', 'person_23'      # Shows the previously hidden elements
      #
      def toggle(*ids)
        call "#{JQUERY_VAR}(\"#{jquery_ids(ids)}\").toggle"
        #loop_on_multiple_args 'Element.toggle', ids
      end

      # Displays an alert dialog with the given +message+.
      #
      # Example:
      #
      #   # Generates: alert('This message is from Rails!')
      #   page.alert('This message is from Rails!')
      def alert(message)
        call 'alert', message
      end

      # Redirects the browser to the given +location+ using JavaScript, in the same form as +url_for+.
      #
      # Examples:
      #
      #  # Generates: window.location.href = "/mycontroller";
      #  page.redirect_to(:action => 'index')
      #
      #  # Generates: window.location.href = "/account/signup";
      #  page.redirect_to(:controller => 'account', :action => 'signup')
      def redirect_to(location)
        #url = location.is_a?(String) ? location : @context.url_for(location)
        url = location.to_s
        record "window.location.href = #{url.inspect}"
      end

      # Reloads the browser's current +location+ using JavaScript
      #
      # Examples:
      #
      #  # Generates: window.location.reload();
      #  page.reload
      def reload
        record 'window.location.reload()'
      end

      # Calls the JavaScript +function+, optionally with the given +arguments+.
      #
      # If a block is given, the block will be passed to a new JavaScriptGenerator;
      # the resulting JavaScript code will then be wrapped inside <tt>function() { ... }</tt>
      # and passed as the called function's final argument.
      #
      # Examples:
      #
      #   # Generates: Element.replace(my_element, "My content to replace with.")
      #   page.call 'Element.replace', 'my_element', "My content to replace with."
      #
      #   # Generates: alert('My message!')
      #   page.call 'alert', 'My message!'
      #
      #   # Generates:
      #   #     my_method(function() {
      #   #       $("one").show();
      #   #       $("two").hide();
      #   #    });
      #   page.call(:my_method) do |p|
      #      p[:one].show
      #      p[:two].hide
      #   end
      def call(function, *arguments, &block)
        record "#{function}(#{arguments_for_call(arguments, block)})"
      end

      # Assigns the JavaScript +variable+ the given +value+.
      #
      # Examples:
      #
      #  # Generates: my_string = "This is mine!";
      #  page.assign 'my_string', 'This is mine!'
      #
      #  # Generates: record_count = 33;
      #  page.assign 'record_count', 33
      #
      #  # Generates: tabulated_total = 47
      #  page.assign 'tabulated_total', @total_from_cart
      #
      def assign(variable, value)
        record "#{variable} = #{javascript_object_for(value)}"
      end

      # Writes raw JavaScript to the page.
      #
      # Example:
      #
      #  page << "alert('JavaScript with Prototype.');"
      def <<(javascript)
        @lines << javascript
      end

      # Executes the content of the block after a delay of +seconds+. Example:
      #
      #   # Generates:
      #   #     setTimeout(function() {
      #   #     ;
      #   #     new Effect.Fade("notice",{});
      #   #     }, 20000);
      #   page.delay(20) do
      #     page.visual_effect :fade, 'notice'
      #   end
      def delay(seconds = 1)
        record "setTimeout(function() {\n\n"
        yield
        record "}, #{(seconds * 1000).to_i})"
      end

      # Starts a script.aculo.us visual effect. See
      # ActionView::Helpers::ScriptaculousHelper for more information.
      def visual_effect(name, id = nil, options = {})
        record jquery_ui_visual_effect(name, id, options)
      end

      SCRIPTACULOUS_EFFECTS = {
        :appear => {:method => 'fade', :mode => 'show'},
        :blind_down => {:method => 'blind', :mode => 'show', :options => {:direction => 'vertical'}},
        :blind_up => {:method => 'blind', :mode => 'hide', :options => {:direction => 'vertical'}},
        :blind_right => {:method => 'blind', :mode => 'show', :options => {:direction => 'horizontal'}},
        :blind_left => {:method => 'blind', :mode => 'hide', :options => {:direction => 'horizontal'}},
        :bounce_in => {:method => 'bounce', :mode => 'show', :options => {:direction => 'up'}},
        :bounce_out => {:method => 'bounce', :mode => 'hide', :options => {:direction => 'up'}},
        :drop_in => {:method => 'drop', :mode => 'show', :options => {:direction => 'up'}},
        :drop_out => {:method => 'drop', :mode => 'hide', :options => {:direction => 'down'}},
        :fade => {:method => 'fade', :mode => 'hide'},
        :fold_in => {:method => 'fold', :mode => 'hide'},
        :fold_out => {:method => 'fold', :mode => 'show'},
        :grow => {:method => 'scale', :mode => 'show'},
        :shrink => {:method => 'scale', :mode => 'hide'},
        :slide_down => {:method => 'slide', :mode => 'show', :options => {:direction => 'up'}},
        :slide_up => {:method => 'slide', :mode => 'hide', :options => {:direction => 'up'}},
        :slide_right => {:method => 'slide', :mode => 'show', :options => {:direction => 'left'}},
        :slide_left => {:method => 'slide', :mode => 'hide', :options => {:direction => 'left'}},
        :squish => {:method => 'scale', :mode => 'hide', :options => {:origin => "['top','left']"}},
        :switch_on => {:method => 'clip', :mode => 'show', :options => {:direction => 'vertical'}},
        :switch_off => {:method => 'clip', :mode => 'hide', :options => {:direction => 'vertical'}},
        :toggle_appear => {:method => 'fade', :mode => 'toggle'},
        :toggle_slide => {:method => 'slide', :mode => 'toggle', :options => {:direction => 'up'}},
        :toggle_blind => {:method => 'blind', :mode => 'toggle', :options => {:direction => 'vertical'}},
      }

      # Returns a JavaScript snippet to be used on the Ajax callbacks for
      # starting visual effects.
      #
      # If no +element_id+ is given, it assumes "element" which should be a local
      # variable in the generated JavaScript execution context. This can be
      # used for example with +drop_receiving_element+:
      #
      #   <%= drop_receiving_element (...), :loading => visual_effect(:fade) %>
      #
      # This would fade the element that was dropped on the drop receiving
      # element.
      #
      # For toggling visual effects, you can use <tt>:toggle_appear</tt>, <tt>:toggle_slide</tt>, and
      # <tt>:toggle_blind</tt> which will alternate between appear/fade, slidedown/slideup, and
      # blinddown/blindup respectively.
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def jquery_ui_visual_effect(name, element_id = false, js_options = {})
        #element = element_id ? ActiveSupport::JSON.encode(jquery_id((JavaScriptVariableProxy === element_id) ? element_id.as_json : element_id)) : "this"
        if element_id
          element = if element_id =~ /\A<%=.*%>\z/  # if completely using erb
            "\"##{element_id}\""   # USER BEWARE !
          else
            ActiveSupport::JSON.encode(jquery_id((JavaScriptVariableProxy === element_id) ? element_id.as_json : element_id))
          end
        else
          element = "this"
        end

        if SCRIPTACULOUS_EFFECTS.has_key? name.to_sym
          effect = SCRIPTACULOUS_EFFECTS[name.to_sym]
          name = effect[:method]
          mode = effect[:mode]
          js_options = js_options.merge(effect[:options]) if effect[:options]
        end

        js_options[:queue] = if js_options[:queue].is_a?(Hash)
          '{' + js_options[:queue].map {|k, v| k == :limit ? "#{k}:#{v}" : "#{k}:'#{v}'" }.join(',') + '}'
        elsif js_options[:queue]
          "'#{js_options[:queue]}'"
        end if js_options[:queue]

        [:color, :direction, :startcolor, :endcolor].each do |option|
          js_options[option] = "'#{js_options[option]}'" if js_options[option]
        end

        js_options[:duration] = (js_options[:duration] * 1000).to_i if js_options.has_key? :duration

        #if ['fadeIn','fadeOut','fadeToggle'].include?(name)
        #  "$(\"#{jquery_id(element_id)}\").#{name}();"
        #else
          "#{JQUERY_VAR}(#{element}).#{mode || "effect"}(\"#{name}\",#{options_for_javascript(js_options)});"
        #end

      end

      def arguments_for_call(arguments, block = nil)
        arguments << block_to_function(block) if block
        arguments.map { |argument| javascript_object_for(argument) }.join ', '
      end

      private
      def options_for_javascript(options)
        if options.empty?
          '{}'
        else
          "{#{options.keys.map { |k| "#{k}:#{options[k]}" }.sort.join(', ')}}"
        end
      end

      def loop_on_multiple_args(method, ids)
        record(ids.size>1 ?
               "#{javascript_object_for(ids)}.each(#{method})" :
               "#{method}(#{javascript_object_for(ids.first)})")
      end

      def page
        self
      end

      def record(line)
        line = "#{line.to_s.chomp.gsub(/\;\z/, '')};"
        self << line
        line
      end

      def render(*options)
        with_formats(:html) do
          case option = options.first
          when Hash
            @context.render(*options)
          else
            option.to_s
          end
        end
      end

      def with_formats(*args)
        return yield unless @context

        lookup = @context.lookup_context
        begin
          old_formats, lookup.formats = lookup.formats, args
          yield
        ensure
          lookup.formats = old_formats
        end
      end

      def javascript_object_for(object)
        if object.is_a?(String) && object =~ /\A<%=.*%>\z/  # if completely using e
          "\"#{object}\""
        else
          ::ActiveSupport::JSON.encode(object)
        end
      end

      def block_to_function(block)
        generator = self.class.new(@context, &block)
        literal("function() { #{generator.to_s} }")
      end

      def method_missing(method, *arguments)
        JavaScriptProxy.new(self, method.to_s.camelize)
      end
    end
  end

  class JavaScriptProxy < (Rails::VERSION::MAJOR >= 4) ? ::ActiveSupport::ProxyObject : ::ActiveSupport::BasicObject #:nodoc:

    def initialize(generator, root = nil)
      @generator = generator
      @generator << root if root
    end

    def is_a?(klass)
      klass == JavaScriptProxy
    end

    private
    def method_missing(method, *arguments, &block)
      if method.to_s =~ /(.*)=$/
        assign($1, arguments.first)
      else
        call("#{method.to_s.camelize(:lower)}", *arguments, &block)
      end
    end

    def call(function, *arguments, &block)
      append_to_function_chain!("#{function}(#{@generator.send(:arguments_for_call, arguments, block)})")
      self
    end

    def assign(variable, value)
      append_to_function_chain!("#{variable} = #{@generator.send(:javascript_object_for, value)}")
    end

    def function_chain
      @function_chain ||= @generator.instance_variable_get(:@lines)
    end

    def append_to_function_chain!(call)
      function_chain[-1].chomp!(';')
      function_chain[-1] += ".#{call};"
    end
  end

  class JavaScriptElementProxy < JavaScriptProxy #:nodoc:
    def initialize(generator, id)
      id = id.sub(/<%=.*%>/,'').to_s.count('#.*,>+~:[/ ') == 0 ? "##{id}" : id
      #id = id.to_s.count('#.*,>+~:[/ ') == 0 ? "##{id}" : id
      @id = id
      if id =~ /\A#?<%=.*%>\z/  # if completely using erb
        super(generator, "#{::JQUERY_VAR}(\"#{id}\");")  # USER BEWARE !
      else
        super(generator, "#{::JQUERY_VAR}(#{::ActiveSupport::JSON.encode(id)});")
      end
    end

    # Allows access of element attributes through +attribute+. Examples:
    #
    #   page['foo']['style']                  # => $('foo').style;
    #   page['foo']['style']['color']         # => $('blank_slate').style.color;
    #   page['foo']['style']['color'] = 'red' # => $('blank_slate').style.color = 'red';
    #   page['foo']['style'].color = 'red'    # => $('blank_slate').style.color = 'red';
    def [](attribute)
      append_to_function_chain!(attribute)
      self
    end

    def []=(variable, value)
      assign(variable, value)
    end

    def replace_html(*options_for_render)
      call 'html', @generator.send(:render, *options_for_render)
    end

    def replace(*options_for_render)
      call 'replaceWith', @generator.send(:render, *options_for_render)
    end

    def reload(options_for_replace = {})
      replace(options_for_replace.merge({ :partial => @id.to_s.sub(/^#/,'') }))
    end

    def value()
      call 'val()'
    end

    def value=(value)
      call 'val', value
    end
  end

  class JavaScriptVariableProxy < JavaScriptProxy #:nodoc:
    def initialize(generator, variable)
      @variable = JsonLiteral.new(variable)
      @empty    = true # only record lines if we have to.  gets rid of unnecessary linebreaks
      super(generator)
    end

    # The JSON Encoder calls this to check for the +to_json+ method
    # Since it's a blank slate object, I suppose it responds to anything.
    def respond_to?(*)
      true
    end

    def as_json(options = nil)
      @variable
    end

    private
    def append_to_function_chain!(call)
      @generator << @variable if @empty
      @empty = false
      super
    end
  end

  class JavaScriptCollectionProxy < JavaScriptProxy #:nodoc:
    ENUMERABLE_METHODS_WITH_RETURN = [:all, :any, :collect, :map, :detect, :find, :find_all, :select, :max, :min, :partition, :reject, :sort_by, :in_groups_of, :each_slice] unless defined? ENUMERABLE_METHODS_WITH_RETURN
    ENUMERABLE_METHODS = ENUMERABLE_METHODS_WITH_RETURN + [:each] unless defined? ENUMERABLE_METHODS
    attr_reader :generator
    delegate :arguments_for_call, :to => :generator

    def initialize(generator, pattern)
      super(generator, @pattern = pattern)
    end

    def each_slice(variable, number, &block)
      if block
        enumerate :eachSlice, :variable => variable, :method_args => [number], :yield_args => %w(value index), :return => true, &block
      else
        add_variable_assignment!(variable)
        append_enumerable_function!("eachSlice(#{::ActiveSupport::JSON.encode(number)});")
      end
    end

    def grep(variable, pattern, &block)
      enumerate :grep, :variable => variable, :return => true, :method_args => [JsonLiteral.new(pattern.inspect)], :yield_args => %w(value index), &block
    end

    def in_groups_of(variable, number, fill_with = nil)
      arguments = [number]
      arguments << fill_with unless fill_with.nil?
      add_variable_assignment!(variable)
      append_enumerable_function!("inGroupsOf(#{arguments_for_call arguments});")
    end

    def inject(variable, memo, &block)
      enumerate :inject, :variable => variable, :method_args => [memo], :yield_args => %w(memo value index), :return => true, &block
    end

    def pluck(variable, property)
      add_variable_assignment!(variable)
      append_enumerable_function!("pluck(#{::ActiveSupport::JSON.encode(property)});")
    end

    def zip(variable, *arguments, &block)
      add_variable_assignment!(variable)
      append_enumerable_function!("zip(#{arguments_for_call arguments}")
      if block
        function_chain[-1] += ", function(array) {"
        yield JsonLiteral.new('array')
        add_return_statement!
        @generator << '});'
      else
        function_chain[-1] += ');'
      end
    end

    private
    def method_missing(method, *arguments, &block)
      if ENUMERABLE_METHODS.include?(method)
        returnable = ENUMERABLE_METHODS_WITH_RETURN.include?(method)
        variable   = arguments.first if returnable
        enumerate(method, {:variable => (arguments.first if returnable), :return => returnable, :yield_args => %w(value index)}, &block)
      else
        super
      end
    end

    # Options
    #   * variable - name of the variable to set the result of the enumeration to
    #   * method_args - array of the javascript enumeration method args that occur before the function
    #   * yield_args - array of the javascript yield args
    #   * return - true if the enumeration should return the last statement
    def enumerate(enumerable, options = {}, &block)
      options[:method_args] ||= []
      options[:yield_args]  ||= []
      yield_args  = options[:yield_args] * ', '
      method_args = arguments_for_call options[:method_args] # foo, bar, function
      method_args << ', ' unless method_args.blank?
      add_variable_assignment!(options[:variable]) if options[:variable]
      append_enumerable_function!("#{enumerable.to_s.camelize(:lower)}(#{method_args}function(#{yield_args}) {")
      # only yield as many params as were passed in the block
      yield(*options[:yield_args].collect { |p| JavaScriptVariableProxy.new(@generator, p) }[0..block.arity-1])
      add_return_statement! if options[:return]
      @generator << '});'
    end

    def add_variable_assignment!(variable)
      function_chain.push("var #{variable} = #{function_chain.pop}")
    end

    def add_return_statement!
      unless function_chain.last =~ /return/
        function_chain.push("return #{function_chain.pop.chomp(';')};")
      end
    end

    def append_enumerable_function!(call)
      function_chain[-1].chomp!(';')
      function_chain[-1] += ".#{call}"
    end
  end

  class JavaScriptElementCollectionProxy < JavaScriptCollectionProxy #:nodoc:\
    def initialize(generator, pattern)
      super(generator, "#{::JQUERY_VAR}(#{::ActiveSupport::JSON.encode(pattern)})")
    end
  end
end
