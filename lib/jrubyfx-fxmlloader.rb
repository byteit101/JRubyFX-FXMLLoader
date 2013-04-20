#GPLv2 only classpath (aka java license)

require 'java'

# Update load path to include the JavaFX runtime and fail nicely if we can't find it
begin
  if ENV['JFX_DIR']
    $LOAD_PATH << ENV['JFX_DIR']
  else #should we check for 1.7 vs 1.8? oh well, adding extra paths won't hurt anybody (maybe performance loading)
    jfx_path = ENV_JAVA["sun.boot.library.path"]
    $LOAD_PATH << if jfx_path.include? ":\\" and !jfx_path.include? "/" # can be tricked, but should work fine
      #windows
      jfx_path.gsub(/\\bin[\\]*$/i, "\\lib")
    else
      # *nix
      jfx_path.gsub(/[\/\\][amdix345678_]+$/, "") # strip i386 or amd64 (including variants). TODO: ARM
    end
  end

  # Java 8 (after ea-b75) and above has JavaFX as part of the normal distib, only require it if we are 7 or below
  jre = ENV_JAVA["java.runtime.version"].match %r{^(?<version>(?<major>\d+)\.(?<minor>\d+))\.(?<patch>\d+)(_\d+)?-?(?<release>ea|u\d)?(-?b(?<build>\d+))?}
  require 'jfxrt.jar' if ENV['JFX_DIR'] or
    jre[:version].to_f < 1.8 or
    (jre[:version].to_f == 1.8 and jre[:release] == 'ea' and jre[:build].to_i < 75)

  # Attempt to load a javafx class
  Java.javafx.application.Application
rescue  LoadError, NameError
  puts "JavaFX runtime not found.  Please install Java 7u6 or newer or set environment variable JFX_DIR to the folder that contains jfxrt.jar "
  puts "If you have Java 7u6 or later, this is a bug. Please report to the issue tracker on github. Include your OS version, 32/64bit, and architecture (x86, ARM, PPC, etc)"
  exit -1
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
com.sun.javafx.fxml.expression.Expression
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

FXL = java_import('javafx.fxml.FXMLLoader')[0]
class FxmlLoader
  attr_accessor :location, :root, :template, :builderFactory, :namespace, :staticLoad
  attr_reader :controller
  FX_NAMESPACE_VERSION="1"
  def initialize(url=nil, ctrlr=nil, resourcs=nil, buildFactory=nil, charset=nil, loaders=nil)
    @location = url
    @controller = ctrlr
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
    @namespace = {}
    @packages = []
    @classes = {}
    @root = nil
    @charset = charset || Charset.forName(FXL::DEFAULT_CHARSET_NAME)
  end

  def controller=(controller)
    @controller = controller
    if controller
      @namespace.delete(FXL::CONTROLLER_KEYWORD)
    else
      @namespace[FXL::CONTROLLER_KEYWORD] = controller
    end
  end

  def load()
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

	# TODO Rename to loadType() when deprecated static version is removed
	def loadTypeForPackage(packageName, className)
		return loadType(packageName, className)
	end

	def getScriptEngineManager()
		unless @scriptEngineManager
			@scriptEngineManager =  Java.javax.script.ScriptEngineManager.new
			@scriptEngineManager.setBindings(SimpleBindings.new(@namespace))
    end

		return @scriptEngineManager;
  end

	def loadType(packageName, className=nil)
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

class FXTesterC
  def initialize(*args)
    dputs "I got the args"
    dp args
  end

  def do_it(e)
    dputs "done it"
    dp self.instance_variables
    dp e
  end
end

require_relative 'fxmlloader/j8_keypath'
require_relative 'fxmlloader/elts'
require_relative 'fxmlloader/value_elts'
require_relative 'fxmlloader/real_elts'
require_relative 'fxmlloader/rrba' # its da ruby rappa bean adapta!

#fx = FxmlLoader.new(URL.new("file:///home/patrick/NetBeansProjects/FXMLLoader/lib/test.fxml"), FXTesterC.new)
#rt = fx.load
#puts "IT DONE"
#p rt
#p fx.root
#p rt.children[0]
#p rt.children[0].get_right
#p rt.children[0].get_right.get_tabs