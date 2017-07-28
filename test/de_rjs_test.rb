require 'abstract_unit'
require 'active_model'

class Bunny < Struct.new(:Bunny, :id)
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  def to_key() id ? [id] : nil end
end

class DeRjsBaseTest < Minitest::Test
  protected
  def not_supported
    skip "not supported"
  end

  def create_generator
    block = Proc.new { |*args| yield(*args) if block_given? }
    DeRjs::JqueryGenerator.new self, &block
  end

  def generate_js(rjs)
    rewritten_source = DeRjs::Rewriter.rewrite_rjs(rjs)
    generator = DeRjs::JqueryGenerator.new(nil) { eval(rewritten_source)}
    generator.to_s
  end
end


class DeRjsTest < DeRjsBaseTest
  def setup
    super
    @generator = create_generator
    ActiveSupport.escape_html_entities_in_json  = true
  end

  def teardown
    ActiveSupport.escape_html_entities_in_json  = false
  end

  def _evaluate_assigns_and_ivars() end

  def test_insert_html_with_string
    assert_equal '$("#element").prepend("\\u003cp\\u003eThis is a test\\u003c/p\\u003e");',
      generate_js(%Q{ page.insert_html(:top, 'element', '<p>This is a test</p>') })
    assert_equal '$("#element").append("\\u003cp\u003eThis is a test\\u003c/p\u003e");',
      generate_js(%Q{ page.insert_html(:bottom, 'element', '<p>This is a test</p>') })
    assert_equal '$("#element").before("\\u003cp\u003eThis is a test\\u003c/p\u003e");',
      generate_js(%Q{ page.insert_html(:before, 'element', '<p>This is a test</p>') })
    assert_equal '$("#element").after("\\u003cp\u003eThis is a test\\u003c/p\u003e");',
      generate_js(%Q{ page.insert_html(:after, 'element', '<p>This is a test</p>') })
  end

  def test_replace_html_with_string
    assert_equal '$("#element").html("\\u003cp\\u003eThis is a test\\u003c/p\\u003e");',
      generate_js(%Q{ page.replace_html('element', '<p>This is a test</p>') })
  end

  def test_replace_element_with_string
    assert_equal '$("#element").replaceWith("\\u003cdiv id=\"element\"\\u003e\\u003cp\\u003eThis is a test\\u003c/p\\u003e\\u003c/div\\u003e");',
      generate_js(%Q{ page.replace('element', '<div id="element"><p>This is a test</p></div>') })
  end

  def test_insert_html_with_hash
    assert_equal '$("#element").prepend("<%= escape_javascript(render(:partial => "post", :locals => {:ab => "cd"})) %>");',
      generate_js(%Q{ page.insert_html(:top, 'element', :partial => "post", :locals => {:ab => "cd"}) })
  end

  def test_replace_html_with_hash
    assert_equal '$("#element").html("<%= escape_javascript(render(:partial => "post", :locals => {:ab => "cd"})) %>");',
      generate_js(%Q{ page.replace_html('element', :partial => "post", :locals => {:ab => "cd"}) })
  end

  def test_replace_element_with_hash
    assert_equal '$("#element").replaceWith("<%= escape_javascript(render(:partial => "post", :locals => {:ab => "cd"})) %>");',
      generate_js(%Q{ page.replace('element', :partial => "post", :locals => {:ab => "cd"}) })
  end


  def test_remove
    assert_equal '$("#foo").remove();',
      generate_js(%Q{ page.remove('foo') })
    assert_equal '$("#foo,#bar,#baz").remove();',
      generate_js(%Q{ page.remove('foo', 'bar', 'baz') })
  end

  def test_show
    assert_equal '$("#foo").show();',
      generate_js(%Q{ page.show('foo') })
    assert_equal '$("#foo,#bar,#baz").show();',
      generate_js(%Q{ page.show('foo', 'bar', 'baz') })
  end

  def test_hide
    assert_equal '$("#foo").hide();',
      generate_js(%Q{ page.hide('foo') })
    assert_equal '$("#foo,#bar,#baz").hide();',
      generate_js(%Q{ page.hide('foo', 'bar', 'baz') })
  end

  def test_toggle
    assert_equal '$("#foo").toggle();',
      generate_js(%Q{ page.toggle('foo') })
    assert_equal '$("#foo,#bar,#baz").toggle();',
      generate_js(%Q{ page.toggle('foo', 'bar', 'baz') })
  end

  def test_alert
    assert_equal 'alert("hello");', generate_js(%Q{ page.alert('hello') })
  end

  def test_redirect_to
    assert_equal 'window.location.href = "http://www.example.com/welcome?a=b&c=d";',
      generate_js(%Q{ page.redirect_to("http://www.example.com/welcome?a=b&c=d") })
    assert_equal 'window.location.href = "<%= url_for(:action => \'welcome\') %>";',
      generate_js(%Q{ page.redirect_to(:action => 'welcome') })
  end

  def test_reload
    assert_equal 'window.location.reload();',
      generate_js(%Q{ page.reload })
  end

  def test_delay
    not_supported

    @generator.delay(20) do
      @generator.hide('foo')
    end

    assert_equal "setTimeout(function() {\n;\n$(\"#foo\").hide();\n}, 20000);", @generator.to_s
  end

  def test_to_s
    not_supported

    @generator.insert_html(:top, 'element', '<p>This is a test</p>')
    @generator.insert_html(:bottom, 'element', '<p>This is a test</p>')
    @generator.remove('foo', 'bar')
    @generator.replace_html('baz', '<p>This is a test</p>')

    assert_equal <<-EOS.chomp, @generator.to_s
$("#element").prepend("\\u003cp\\u003eThis is a test\\u003c/p\\u003e");
$("#element").append("\\u003cp\\u003eThis is a test\\u003c/p\\u003e");
$("#foo,#bar").remove();
$("#baz").html("\\u003cp\\u003eThis is a test\\u003c/p\\u003e");
    EOS
  end

  def test_element_access
    assert_equal %($("#hello");), generate_js(%Q{ page['hello'] })
  end

  def test_element_access_on_variable
    assert_raises DeRjs::Rewriter::Erbify::MustTranslateManually do
      assert_equal %($("#<%= 'hello' + @var %>");), generate_js(%Q{ page['hello' + @var] })
    end
    assert_raises DeRjs::Rewriter::Erbify::MustTranslateManually do
      assert_equal %($("#<%= 'hello' + @var %>").hide();), generate_js(%Q{ page['hello' + @var].hide })
    end
  end

  def test_element_access_on_records
    assert_raises DeRjs::Rewriter::Erbify::MustTranslateManually do
      assert_equal %($("#<%= Bunny.new(:id => 5) %>");), generate_js(%Q{ page[Bunny.new(:id => 5)] })
    end
    assert_raises DeRjs::Rewriter::Erbify::MustTranslateManually do
      assert_equal %($("#<%= Bunny.new %>");), generate_js(%Q{ page[Bunny.new] })
    end
  end


  def test_element_proxy_one_deep
    assert_equal %($("#hello").hide();), generate_js(%Q{ page['hello'].hide })
  end

  def test_element_proxy_variable_access
    assert_equal %($("#hello").style;), generate_js(%Q{ page['hello']['style'] })
  end

  def test_element_proxy_variable_access_with_assignment
    assert_equal %($("#hello").style.color = "red";), generate_js(%Q{ page['hello']['style']['color'] = 'red' })
  end

  def test_element_proxy_assignment
    assert_equal %($("#hello").width = 400;), generate_js(%Q{ page['hello'].width = 400 })
  end

  def test_element_proxy_two_deep
    @generator['hello'].hide("first").clean_whitespace
    assert_equal %($("#hello").hide("first").cleanWhitespace();), @generator.to_s
  end

  def test_select_access
    assert_equal %($("div.hello");), @generator.select('div.hello')
  end

  def test_select_proxy_one_deep
    assert_equal %($("p.welcome b").first().hide();), generate_js(%Q{ page.select('p.welcome b').first.hide })
  end

  def test_visual_effect
    assert_equal %($(\"#blah\").effect(\"puff\",{});),
      generate_js(%Q{ page.visual_effect(:puff,'blah') })
  end

  def test_visual_effect_toggle
    assert_equal %($(\"#blah\").toggle(\"fade\",{});),
      generate_js(%Q{ page.visual_effect(:toggle_appear,'blah') })
  end

  def test_visual_effect_with_variable
    assert_equal %($(\"#<%= "blah" + blah.id %>\").toggle(\"fade\",{});),
      generate_js(%Q{ page.visual_effect(:toggle_appear,"blah" + blah.id) })
  end

  def test_sortable
    assert_equal %(Sortable.create("blah", {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize("blah")})}});),
      @generator.sortable('blah', :url => { :action => "order" })
    assert_equal %(Sortable.create("blah", {onUpdate:function(){new Ajax.Request('http://www.example.com/order', {asynchronous:false, evalScripts:true, parameters:Sortable.serialize("blah")})}});),
      @generator.sortable('blah', :url => { :action => "order" }, :type => :synchronous)
  end

  def test_draggable
    assert_equal %(new Draggable("blah", {});),
      @generator.draggable('blah')
  end

  def test_drop_receiving
    assert_equal %(Droppables.add("blah", {onDrop:function(element){new Ajax.Request('http://www.example.com/order', {asynchronous:true, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}});),
      @generator.drop_receiving('blah', :url => { :action => "order" })
    assert_equal %(Droppables.add("blah", {onDrop:function(element){new Ajax.Request('http://www.example.com/order', {asynchronous:false, evalScripts:true, parameters:'id=' + encodeURIComponent(element.id)})}});),
      @generator.drop_receiving('blah', :url => { :action => "order" }, :type => :synchronous)
  end

  def test_collection_first_and_last
    js = generate_js(%Q{
    page.select('p.welcome b').first.hide()
    page.select('p.welcome b').last.show()
    })
    assert_equal <<-EOS.strip, js
$("p.welcome b").first().hide();
$("p.welcome b").last().show();
      EOS
  end

  def test_collection_proxy_with_each
    not_supported

    @generator.select('p.welcome b').each do |value|
      value.remove_class_name 'selected'
    end
    @generator.select('p.welcome b').each do |value, index|
      @generator.visual_effect :highlight, value
    end
    assert_equal <<-EOS.strip, @generator.to_s
$("p.welcome b").each(function(value, index) {
value.removeClassName("selected");
});
$("p.welcome b").each(function(value, index) {
$("#value").effect("highlight",{});
});
      EOS
  end

  def test_collection_proxy_on_collect
    not_supported

    @generator.select('p').collect('a') { |para| para.show }
    @generator.select('p').collect { |para| para.hide }
    assert_equal <<-EOS.strip, @generator.to_s
var a = $("p").collect(function(value, index) {
return value.show();
});
$("p").collect(function(value, index) {
return value.hide();
});
    EOS
    @generator = create_generator
  end

  def test_collection_proxy_with_grep
    not_supported

    @generator.select('p').grep 'a', /^a/ do |value|
      @generator << '(value.className == "welcome")'
    end
    @generator.select('p').grep 'b', /b$/ do |value, index|
      @generator.call 'alert', value
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $("p").grep(/^a/, function(value, index) {
return (value.className == "welcome");
});
var b = $("p").grep(/b$/, function(value, index) {
alert(value);
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_inject
    not_supported

    @generator.select('p').inject 'a', [] do |memo, value|
      @generator << '(value.className == "welcome")'
    end
    @generator.select('p').inject 'b', nil do |memo, value, index|
      @generator.call 'alert', memo
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $("p").inject([], function(memo, value, index) {
return (value.className == "welcome");
});
var b = $("p").inject(null, function(memo, value, index) {
alert(memo);
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_pluck
    js = generate_js(%Q{ page.select('p').pluck('a', 'className') })
    assert_equal %(var a = $("p").pluck("className");), js
  end

  def test_collection_proxy_with_zip
    not_supported

    ActionView::Helpers::JavaScriptCollectionProxy.new(@generator, '[1, 2, 3]').zip('a', [4, 5, 6], [7, 8, 9])
    ActionView::Helpers::JavaScriptCollectionProxy.new(@generator, '[1, 2, 3]').zip('b', [4, 5, 6], [7, 8, 9]) do |array|
      @generator.call 'array.reverse'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = [1, 2, 3].zip([4,5,6], [7,8,9]);
var b = [1, 2, 3].zip([4,5,6], [7,8,9], function(array) {
return array.reverse();
});
    EOS
  end

  def test_collection_proxy_with_find_all
    not_supported

    @generator.select('p').find_all 'a' do |value, index|
      @generator << '(value.className == "welcome")'
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $("p").findAll(function(value, index) {
return (value.className == "welcome");
});
    EOS
  end

  def test_collection_proxy_with_in_groups_of
    not_supported

    @generator.select('p').in_groups_of('a', 3)
    @generator.select('p').in_groups_of('a', 3, 'x')
    assert_equal <<-EOS.strip, @generator.to_s
var a = $("p").inGroupsOf(3);
var a = $("p").inGroupsOf(3, "x");
    EOS
  end

  def test_collection_proxy_with_each_slice
    not_supported

    @generator.select('p').each_slice('a', 3)
    @generator.select('p').each_slice('a', 3) do |group, index|
      group.reverse
    end

    assert_equal <<-EOS.strip, @generator.to_s
var a = $("p").eachSlice(3);
var a = $("p").eachSlice(3, function(value, index) {
return value.reverse();
});
    EOS
  end

  #def test_debug_rjs
    #ActionView::Base.debug_rjs = true
    #@generator['welcome'].replace_html 'Welcome'
    #assert_equal "try {\n$(\"#welcome\").html(\"Welcome\");\n} catch (e) { alert('RJS error:\\n\\n' + e.toString()); alert('$(\\\"#welcome\\\").html(\\\"Welcome\\\");'); throw e }", @generator.to_s
  #ensure
    #ActionView::Base.debug_rjs = false
  #end

  def test_literal
    not_supported

    literal = @generator.literal("function() {}")
    assert_equal "function() {}", ActiveSupport::JSON.encode(literal)
    assert_equal "", @generator.to_s
  end

  def test_class_proxy
    @generator.form.focus('my_field')
    assert_equal "Form.focus(\"my_field\");", @generator.to_s
  end

  def test_call_with_block
    not_supported

    @generator.call(:before)
    @generator.call(:my_method) do |p|
      p[:one].show
      p[:two].hide
    end
    @generator.call(:in_between)
    @generator.call(:my_method_with_arguments, true, "hello") do |p|
      p[:three].visual_effect(:highlight)
    end
    assert_equal "before();\nmy_method(function() { $(\"#one\").show();\n$(\"#two\").hide(); });\nin_between();\nmy_method_with_arguments(true, \"hello\", function() { $(\"#three\").visualEffect(\"highlight\"); });", @generator.to_s
  end

  def test_class_proxy_call_with_block
    not_supported

    @generator.my_object.my_method do |p|
      p[:one].show
      p[:two].hide
    end
    assert_equal "MyObject.myMethod(function() { $(\"#one\").show();\n$(\"#two\").hide(); });", @generator.to_s
  end
end
