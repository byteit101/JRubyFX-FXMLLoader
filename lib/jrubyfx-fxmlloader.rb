=begin
 * Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
=end


begin
  # Attempt to load a javafx class
  Java.javafx.application.Application
rescue  LoadError, NameError
  puts "JRubyFX and JavaFX runtime not found.  Please load this file from JRubyFX"
  exit -2
end

#java_import 'javax.xml.stream.util.StreamReaderDelegate'
#java_import 'javax.xml.stream.XMLStreamException', 'javax.xml.stream.XMLInputFactory',
#  'java.io.InputStreamReader', 'javax.xml.stream.XMLStreamConstants'
java_import 'java.net.URL', 'java.nio.charset.Charset', 'java.lang.ClassNotFoundException'
#java_import 'javafx.fxml.LoadException'
java_import 'javafx.fxml.JavaFXBuilderFactory'
java_import 'java.lang.InstantiationException', 'java.lang.IllegalAccessException'

java_import *%w[com.sun.javafx.Logging
java.io.IOException
java.io.InputStream
java.io.InputStreamReader
java.lang.reflect.Constructor
java.lang.reflect.InvocationTargetException
java.lang.reflect.Modifier
java.lang.reflect.ParameterizedType
java.lang.reflect.Type
java.net.URL
java.nio.charset.Charset
java.util.AbstractMap
java.util.ArrayList
java.util.Collections
java.util.HashMap
java.util.LinkedList
java.util.List
java.util.Map
java.util.ResourceBundle
java.util.Set
java.util.regex.Pattern

javafx.beans.DefaultProperty
javafx.beans.property.Property
javafx.beans.value.ChangeListener
javafx.beans.value.ObservableValue
javafx.collections.FXCollections
javafx.collections.ListChangeListener
javafx.collections.MapChangeListener
javafx.collections.ObservableList
javafx.collections.ObservableMap
javafx.event.Event
javafx.event.EventHandler
javafx.event.EventType
javafx.util.Builder
javafx.util.BuilderFactory
javafx.util.Callback

javax.script.Bindings
javax.script.ScriptContext
javax.script.ScriptEngine
javax.script.ScriptEngineManager
javax.script.ScriptException
javax.script.SimpleBindings
javax.xml.stream.XMLInputFactory
javax.xml.stream.XMLStreamConstants
javax.xml.stream.XMLStreamException
javax.xml.stream.XMLStreamReader
javax.xml.stream.util.StreamReaderDelegate

com.sun.javafx.beans.IDProperty
com.sun.javafx.fxml.LoadListener
com.sun.javafx.fxml.ObservableListChangeEvent
com.sun.javafx.fxml.ObservableMapChangeEvent
com.sun.javafx.fxml.PropertyChangeEvent
java.net.MalformedURLException
java.security.AccessController
java.security.PrivilegedAction
java.util.Locale
java.lang.NoSuchMethodException
java.util.StringTokenizer
sun.reflect.misc.ConstructorUtil
sun.reflect.misc.FieldUtil
sun.reflect.misc.MethodUtil
sun.reflect.misc.ReflectUtil]

class LoadException < Exception
  def initialize(stuff)
    super
  end
end
$DEBUG_IT_FXML = false
def dp(*args)
  p *args if $DEBUG_IT_FXML
end
def dputs(*args)
  puts *args if $DEBUG_IT_FXML
end
def dprint(*args)
  print *args if $DEBUG_IT_FXML
end

# Override to safely get ruby class of non-java_class objects
class Class
  def ruby_class
    self
  end
end

#Long to avoid collisions
MAGIC_FXML_JAVAFX_JRUBYFX_FXMLLOADER__FILE__LOCATION_SUPER_SECRET = __FILE__

FXL = java_import('javafx.fxml.FXMLLoader')[0]
class FxmlLoader
  attr_accessor :location, :root, :template, :builderFactory, :namespace, :staticLoad, :current, :controllerFactory
  attr_reader :controller
  FX_NAMESPACE_VERSION="1"
  def initialize(url=nil, ctrlr=nil, resourcs=nil, buildFactory=nil, charset=nil, loaders=nil)
    @location = url
    @builderFactory = buildFactory || JavaFXBuilderFactory.new
    @template = false
    if resourcs
      dputs "WHOA WHOAT!!!! resources"
      dp resourcs
    end
    if loaders
      dputs "WHOA WHOAT!!!! loaders"
      dp loaders
    end
    @namespace = FXCollections.observableHashMap()
    self.controller = ctrlr
    @packages = []
    @classes = {}
    @root = nil
    @charset = charset || Charset.forName(FXL::DEFAULT_CHARSET_NAME)
  end

  def controller=(controller)
    @controller = controller
    unless controller
      @namespace.delete(FXL::CONTROLLER_KEYWORD)
    else
      @namespace[FXL::CONTROLLER_KEYWORD] = controller
    end
  end

  def load()
    dp "This is the namespace", @namespace
    # TODO: actually open it properly
    inputStream = @location.open_stream
    if @template
      @root = nil
    else
      clearImports
    end

    @namespace[FXL::LOCATION_KEY] = @location
    @namespace[FXL::RESOURCES_KEY] = @resources

    @script_engine = nil

    begin
      xmlInputFactory = XMLInputFactory.newFactory
      xmlInputFactory.setProperty("javax.xml.stream.isCoalescing", true)

			# Some stream readers incorrectly report an empty string as the prefix
			# for the default namespace; correct this as needed
			inputStreamReader = InputStreamReader.new(inputStream, @charset);
			@xmlStreamReader = SRDelegateClass.new(xmlInputFactory.createXMLStreamReader(inputStreamReader))
    rescue XMLStreamException => e
      raise LoadException.new(e)
    end

    # Parse the XML stream
		begin
			while @xmlStreamReader.hasNext()
        dputs "......"
        event = @xmlStreamReader.next();
        dputs "#{event} aout happened, dude"
				case event
        when XMLStreamConstants::PROCESSING_INSTRUCTION
          dputs "processing instr"
          processProcessingInstruction
        when XMLStreamConstants::COMMENT
          dputs "processing comment"
          processComment
        when XMLStreamConstants::START_ELEMENT
          dputs "processing start"
          processStartElement
        when XMLStreamConstants::END_ELEMENT
          dputs "processing end"
          processEndElement
        when XMLStreamConstants::CHARACTERS
          dputs "processing chars"
          processCharacters
        end
      end
		rescue XMLStreamException => exception
			raise Exception.new(exception)
    end
    dputs "Saving stuff!!!!s"
    if @controller
      # TODO: initialize should be called here
      # Inject controller fields
      @controller.instance_variable_set("@" + FXL::LOCATION_KEY, @location)
      @controller.instance_variable_set("@" + FXL::RESOURCES_KEY, @resources)
    end


    @xmlStreamReader = nil
    return @root
  end

  def clearImports
    @packages.clear
    @classes.clear
  end

  def processProcessingInstruction
		piTarget = @xmlStreamReader.getPITarget().strip
		if piTarget == FXL::LANGUAGE_PROCESSING_INSTRUCTION
			processLanguage
		elsif piTarget == FXL::IMPORT_PROCESSING_INSTRUCTION
			processImport
    end
  end

  def processLanguage
		if @scriptEngine
			raise LoadException.new("Page language already set.")
    end

		language = @xmlStreamReader.getPIData()

		if @loadListener
			@loadListener.readLanguageProcessingInstruction(language)
    end

		unless staticLoad
			scriptEngineManager = getScriptEngineManager()
			scriptEngine = scriptEngineManager.getEngineByName(language)
			scriptEngine.setBindings(scriptEngineManager.getBindings(), ScriptContext.ENGINE_SCOPE)
    end
  end

  def processImport
		target = @xmlStreamReader.getPIData().strip

		if @loadListener
			@loadListener.readImportProcessingInstruction(target)
    end

		if target.end_with?(".*")
			importPackage(target[0,target.length - 2])
		else
			importClass(target)
    end
  end

  def processComment
    @loadListener.readComment(@xmlStreamReader.text) if @loadListener
  end

  def processStartElement()
		# Create the element
		createElement();

		# Process the start tag
		@current.processStartElement();

		# Set the root value
		unless @root
			@root = @current.value;
    end
  end

	def createElement()
		prefix = @xmlStreamReader.getPrefix();
		localName = @xmlStreamReader.getLocalName();

		if !prefix
			i = localName.rindex('.')

			if localName[(i ? i : -1) + 1] == localName[(i ? i : -1) + 1].downcase
				name = localName[((i ? i : -1) + 1)..-1]

				if (i == nil)
					# This is an instance property
					if @loadListener
						@loadListener.beginPropertyElement(name, nil)
          end

					@current = PropertyElement.new(@current, @xmlStreamReader, @loadListener, self, name, nil)
				else
					# This is a static property
					sourceType = getType(localName[0, i]);
					if sourceType
						if @loadListener
							@loadListener.beginPropertyElement(name, sourceType);
            end

						@current = PropertyElement.new(@current, @xmlStreamReader, @loadListener, self,name, sourceType)
					elsif (@staticLoad)
						# The source type was not recognized
						if @loadListener
							@loadListener.beginUnknownStaticPropertyElement(localName);
            end

						@current = FXL::UnknownStaticPropertyElement.new
					else
						raise LoadException.new(localName + " is not a valid property.");
          end
        end
			else
				if (@current == nil && @root)
					raise LoadException.new("Root value already specified.");
        end

				type = getType(localName);
        prefixz = @xmlStreamReader.getLocation().getLineNumber().to_s + ": "
        numz = 1
        pppn = @current
        while pppn
          numz+=1
          pppn = pppn.parent
        end
        prefixz = (" " * numz) + prefixz
        dputs "#{prefixz}Creating new stuff"
        dprint prefixz
        dp localName
        dprint prefixz
        dp type

				if type
					if @loadListener
						@loadListener.beginInstanceDeclarationElement(type);
          end
					@current = InstanceDeclarationElement.new(@current, @xmlStreamReader, @loadListener, self, type)
				elsif (@staticLoad)
					# The type was not recognized
					if @loadListener
						@loadListener.beginUnknownTypeElement(localName);
          end

					@current = UnknownTypeElement.new(@current, @xmlStreamReader, @loadListener, self)
				else
          raise LoadException.new(localName + " is not a valid type.");
        end
      end
		elsif prefix == FXL::FX_NAMESPACE_PREFIX
			if localName == FXL::INCLUDE_TAG
				if @loadListener
					@loadListener.beginIncludeElement()
        end
				@current = IncludeElement.new(@current, @xmlStreamReader, @loadListener, self)
			elsif localName == FXL::REFERENCE_TAG
				if @loadListener
					@loadListener.beginReferenceElement
        end

				@current = ReferenceElement.new(@current, @xmlStreamReader, @loadListener, self)
			elsif localName == FXL::COPY_TAG
				if @loadListener
          @loadListener.beginCopyElement();
        end

				@current = CopyElement.new(@current, @xmlStreamReader, @loadListener, self)
			elsif localName == FXL::ROOT_TAG
				if @loadListener
          @loadListener.beginRootElement();
        end

				@current = RootElement.new(@current, @xmlStreamReader, @loadListener, self)
			elsif localName == FXL::SCRIPT_TAG
				if @loadListener
          @loadListener.beginScriptElement();
        end

				@current = ScriptElement.new(@current, @xmlStreamReader, @loadListener, self)
			elsif localName == FXL::DEFINE_TAG
				if @loadListener
          @loadListener.beginDefineElement();
        end

				@current = DefineElement.new(@current, @xmlStreamReader, @loadListener, self)
			else
				raise LoadException.new(prefix + ":" + localName + " is not a valid element.");
      end
		else
			raise LoadException.new("Unexpected namespace prefix: " + prefix + ".");
    end
  end

  def processEndElement()
    dputs "ending!!!!!!!!"
		@current.processEndElement();
		if @loadListener
			@loadListener.endElement(@current.value);
		end

		# Move up the stack
		@current = @current.parent;
	end

	def processCharacters()
		# Process the characters
		if (!@xmlStreamReader.isWhiteSpace())
			@current.processCharacters();
		end
	end

	def importPackage(name)
		@packages << name
	end

	def importClass(name)
		begin
			loadType(name, true);
		rescue ClassNotFoundException => exception
			raise LoadException.new(exception);
		end
	end
  
  # steal handy methods from activesupport
  # Tries to find a constant with the name specified in the argument string.
  #
  # 'Module'.constantize # => Module
  # 'Test::Unit'.constantize # => Test::Unit
  #
  # The name is assumed to be the one of a top-level constant, no matter
  # whether it starts with "::" or not. No lexical context is taken into
  # account:
  #
  # C = 'outside'
  # module M
  # C = 'inside'
  # C # => 'inside'
  # 'C'.constantize # => 'outside', same as ::C
  # end
  #
  # NameError is raised when the name is not in CamelCase or the constant is
  # unknown.
  def constantize(camel_cased_word)
    names = camel_cased_word.split('.')
    names.shift if names.empty? || names.first.empty?

    names.inject(Object) do |constant, name|
      if constant == Object
        constant.const_get(name)
      else
        candidate = constant.const_get(name)
        next candidate if constant.const_defined?(name, false)
        next candidate unless Object.const_defined?(name)

        # Go down the ancestors to check it it's owned
        # directly before we reach Object or the end of ancestors.
        constant = constant.ancestors.inject do |const, ancestor|
          break const if ancestor == Object
          break ancestor if ancestor.const_defined?(name, false)
          const
        end

        # owner is in Object, so raise
        constant.const_get(name, false)
      end
    end
  end

  # Tries to find a constant with the name specified in the argument string.
  #
  # 'Module'.safe_constantize # => Module
  # 'Test::Unit'.safe_constantize # => Test::Unit
  #
  # The name is assumed to be the one of a top-level constant, no matter
  # whether it starts with "::" or not. No lexical context is taken into
  # account:
  #
  # C = 'outside'
  # module M
  # C = 'inside'
  # C # => 'inside'
  # 'C'.safe_constantize # => 'outside', same as ::C
  # end
  #
  # +nil+ is returned when the name is not in CamelCase or the constant (or
  # part of it) is unknown.
  #
  # 'blargle'.safe_constantize # => nil
  # 'UnknownModule'.safe_constantize # => nil
  # 'UnknownModule::Foo::Bar'.safe_constantize # => nil
  def safe_constantize(camel_cased_word)
    constantize(camel_cased_word)
  rescue NameError => e
    raise unless e.message =~ /(uninitialized constant|wrong constant name) #{const_regexp(camel_cased_word)}$/ ||
      e.name.to_s == camel_cased_word.to_s
  rescue ArgumentError => e
    raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
  end

	def getType(name)
		type = nil

		if name[0] == name[0].downcase
			# This is a fully-qualified class name
			begin
				type = loadType(name, false);
			rescue ClassNotFoundException => exception
				# No-op
			end
		else
			# This is an unqualified class name
			type = @classes[name];

			unless type
				# The class has not been loaded yet; look it up
				@packages.each do |packageName|
					begin
						type = loadTypeForPackage(packageName, name);
					rescue ClassNotFoundException => exception
						# No-op
					end
          break if type
				end
        unless type
          # check for ruby
          # TODO: this should require an import or something perhaps? need to think more about this?
          begin
						type = constantize(name)
					rescue 
						# No-op
					end
        end
        @classes[name] = type if type
			end
		end

		return type;
	end

	def loadType(name, cache)
		i = name.index('.');
		n = name.length;
		while (i &&
          i < n &&
          name[i + 1] == name[i + 1].downcase)
			i = name.index('.', i + 1);
		end

		if (i == nil || i == n)
			raise ClassNotFoundException.new();
		end

		packageName = name[0, i];
		className = name[(i + 1)..-1];

		type = loadTypeForPackage(packageName, className);

		if (cache)
			@classes[className]  = type
		end

		return type;
	end


	def getScriptEngineManager()
		unless @scriptEngineManager
			@scriptEngineManager =  Java.javax.script.ScriptEngineManager.new
			@scriptEngineManager.setBindings(SimpleBindings.new(@namespace))
    end

		return @scriptEngineManager;
  end

	def loadTypeForPackage(packageName, className=nil)
		packageName = (packageName + "." + className.gsub('.', '$')) if className
    #TODO: fix for ruby stuff
		return Java.java.lang.Class::forName(packageName, true, FXL::default_class_loader);
  end
  def compareJFXVersions(rtVer, nsVer)

    retVal = 0;

		if (rtVer == nil || "" == (rtVer)			|| nsVer == nil || "" == (nsVer))
			return retVal;
    end

		if (rtVer == (nsVer))
			return retVal;
    end

		# version string can contain '-'
    dashIndex = rtVer.index("-");
    dashIndex = -1 unless dashIndex
		if (dashIndex > 0)

			rtVer = rtVer[0, dashIndex]
    end

		# or "_"
    underIndex = rtVer.index("_");
    underIndex = -1 unless underIndex
		if (underIndex > 0)

			rtVer = rtVer[0, underIndex]
    end

		# do not try to compare if the string is not valid version format
		if (!rtVer.match(/^(\d+)(\.\d+)*$/)			|| !nsVer.match(/^(\d+)(\.\d+)*$/))
			return retVal;
    end

    nsVerTokenizer = StringTokenizer.new(nsVer, ".");
		rtVerTokenizer = StringTokenizer.new(rtVer, ".");
		nsDigit = 0
    rtDigit = 0;
		rtVerEnd = false;

		while (nsVerTokenizer.hasMoreTokens() && retVal == 0)
			nsDigit = nsVerTokenizer.nextToken().to_i
			if (rtVerTokenizer.hasMoreTokens())
				rtDigit = rtVerTokenizer.nextToken().to_i
				retVal = rtDigit - nsDigit;
			else
				rtVerEnd = true;
				break;
      end
    end

		if (rtVerTokenizer.hasMoreTokens() && retVal == 0)
			rtDigit = rtVerTokenizer.nextToken().to_i
			if (rtDigit > 0)
				retVal = 1;
      end
    end

		if (rtVerEnd)
			if (nsDigit > 0)
				retVal = -1;
			else
				while (nsVerTokenizer.hasMoreTokens())
					nsDigit = nsVerTokenizer.nextToken().to_i
					if (nsDigit > 0)
						retVal = -1;
						break;
          end
        end
      end
    end

		return retVal;
  end
end


class SRDelegateClass < StreamReaderDelegate
  def getPrefix()

    prefix = super

    if prefix	&& prefix.length == 0
      prefix = nil
    end
    return prefix;
  end

  def getAttributePrefix(index)
    prefix = super

    if prefix	&& prefix.length == 0
      prefix = nil
    end
    return prefix;
  end
end

require_relative 'fxmlloader/j8_expression_value'
require_relative 'fxmlloader/elts'
require_relative 'fxmlloader/value_elts'
require_relative 'fxmlloader/real_elts'
require_relative 'fxmlloader/rrba'
require_relative 'fxmlloader/rorba'
require_relative 'FXMLLoader-j8.jar'

java_import 'org.jruby.jfx8.KeyPath'
java_import 'org.jruby.jfx8.Expression'


class RRBAdapters < org.jruby.jfx8.RubyBeanAdapter
  def get(names, key)
    RubyWrapperBeanAdapter.for(names)[key]
  end
  def set(names, key, value)
    RubyWrapperBeanAdapter.for(names)[key] = value
  end
  def contains(names, key)
    RubyWrapperBeanAdapter.for(names).has_key? key
  end
end

org.jruby.jfx8.RubyBeanAdapter.load_ruby_space RRBAdapters.new