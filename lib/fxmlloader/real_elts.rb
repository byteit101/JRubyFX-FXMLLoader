class InstanceDeclarationElement < ValueElement
  attr_accessor :type, :constant, :factory

  def initialize(current, xmlStreamReader, loadListener, parentLoader, type)
    super(current, xmlStreamReader, loadListener, parentLoader)
    dputs "new instances! #{type}"
    @type = type;
    @constant = nil;
    @factory = nil;
  end

  def processAttribute( prefix,  localName,  value)
    dputs callz + "Processing #{prefix} for #{localName} on #{type} value: #{value}"
    if (prefix != nil				&& prefix == (FXL::FX_NAMESPACE_PREFIX))
      if (localName == (FXL::FX_VALUE_ATTRIBUTE))
        @value = value;
      elsif (localName == (FXL::FX_CONSTANT_ATTRIBUTE))
        @constant = value;
      elsif (localName == (FXL::FX_FACTORY_ATTRIBUTE))
        @factory = value;
      else
        dputs callz + "SUPER!"
        super(prefix, localName, value);
      end
    else
        dputs callz + "SUPER2!"
      super(prefix, localName, value);
    end
  end

  def constructValue()
    value = nil
    dputs callz  + "building new object when #{@value.inspect}, #{constant.inspect}, #{factory.inspect}"
    if (@value != nil)
      value = RubyWrapperBeanAdapter.coerce(@value, type);
    elsif (constant != nil)
      value = RubyWrapperBeanAdapter.getConstantValue(type, constant);
    elsif (factory != nil)
      factoryMethod = nil
      begin
        factoryMethod = MethodUtil.getMethod(type, factory, []);
      rescue NoSuchMethodException => exception
        raise LoadException.new(exception);
      end

      begin
        value = MethodUtil.invoke(factoryMethod, nil, []);
      rescue IllegalAccessException => exception
        raise LoadException.new(exception);
      rescue InvocationTargetException => exception
        raise LoadException.new(exception);
      end
    else
      value = (parentLoader.builderFactory == nil) ? nil : parentLoader.builderFactory.getBuilder(type);
      dputs callz + "now using #{value.class}"
      if (value.is_a? Builder or (value.respond_to?(:java_object) && value.java_object.is_a?(Builder)))
        begin
          value.size
        rescue java.lang.UnsupportedOperationException => ex
       dputs "########################## WARNING #############################3"
        class << value
          def size
            dputs caller
            dputs "size waz called!"
            6
          end
          def [](x)
            get(x)
          end
          def []=(x,y)
            put(x,y)
          end
          def has_key?(x)
            containsKey(x)
          end
          def to_s
            "something interesting...."
          end
          def inspect
            "something equally interesting...."
          end
        end
      end
      end
      if (value == nil)
        begin
          dputs callz + "attemping it (#{type} => #{type.inspect})"
          #TODO: does this work?
          value = type.ruby_class.new
          dputs callz + "got taaatempt"
          dprint callz
          dp value
        rescue InstantiationException => exception
          raise LoadException.new(exception);
        rescue IllegalAccessException => exception
          raise LoadException.new(exception);
        end
      else

        dputs value.size
        dputs callz + "parent loader is #{parentLoader.builderFactory} and got #{value} for #{type} (#{value.inspect} #{type.inspect}, #{parentLoader.builderFactory.inspect})"
      end
    end

    return value;
  end
end

# Element representing an unknown type
class UnknownTypeElement < ValueElement

  def initialize()
    dputs "oh no...."
  end
  # TODO: cleanup
  # Map type representing an unknown value
  #		def UnknownValueMap extends AbstractMap<String, Object>
  #			def<?> items = ArrayList.new<Object>();
  #			def<String, Object> values = HashMap.new<String, Object>();
  #
  #			def get(Object key)
  #				if (key == nil)
  #					raise NullPointerException.new();
  #				end
  #
  #				return (key == (java_class().getAnnotation(DefaultProperty.java_class).value()))
  #					   ? items : values.get(key);
  #			end
  #
  #			def put(String key, Object value)
  #				if (key == nil)
  #					raise NullPointerException.new();
  #				end
  #
  #				if (key == (java_class().getAnnotation(DefaultProperty.java_class).value()))
  #					raise IllegalArgumentException.new();
  #				end
  #
  #				return values.put(key, value);
  #			end
  #
  #			def entrySet()
  #				return Collections.emptySet();
  #			end
  #		end

  def processEndElement()
    # No-op
  end

  def constructValue()
    return UnknownValueMap.new();
  end
end

# Element representing an include
class IncludeElement < ValueElement
  # TODO: cleanup
  attr_accessor :source, :resources, :charset
  def initialize(current, xmlStreamReader, loadListener, parentLoader)
    super
    @source = nil;
    @resources = parentLoader.resources;
    @charset = parentLoader.charset;
  end

  def processAttribute(prefix,  localName,  value)

    if (prefix == nil)
      if (localName == (FXL::INCLUDE_SOURCE_ATTRIBUTE))
        if (loadListener != nil)
          loadListener.readInternalAttribute(localName, value);
        end

        source = value;
      elsif (localName == (FXL::INCLUDE_RESOURCES_ATTRIBUTE))
        if (loadListener != nil)
          loadListener.readInternalAttribute(localName, value);
        end

        resources = ResourceBundle.getBundle(value, Locale.getDefault(),
          parentLoader.resources.java_class().getClassLoader());
      elsif (localName == (FXL::INCLUDE_CHARSET_ATTRIBUTE))
        if (loadListener != nil)
          loadListener.readInternalAttribute(localName, value);
        end

        charset = Charset.forName(value);
      else
        super(prefix, localName, value);
      end
    else
      super(prefix, localName, value);
    end
  end

  def constructValue()
    if (source == nil)
      raise LoadException.new(FXL::INCLUDE_SOURCE_ATTRIBUTE + " is required.");
    end

    location = nil
    if (source[0] == '/')
      location = classLoader.getResource(source[1..-1]);
    else
      if (location == nil)
        raise LoadException.new("Base location is undefined.");
      end

      location = URL.new(location, source);
    end

    fxmlLoader = FxmlLoader.new(location, controller, resources,
      parentLoader.builderFactory, charset,
      loaders);
    fxmlLoader.parentLoader = parentSelf

    if (isCyclic(parentSelf, fxmlLoader))
      raise IOException.new(
        String.format(
					"Including \"%s\" in \"%s\" created cyclic reference.",
					fxmlLoader.location.toExternalForm(),
					parentSelf.location.toExternalForm()));
    end
    fxmlLoader.setClassLoader(classLoader);
    fxmlLoader.setStaticLoad(staticLoad);

    value = fxmlLoader.load();

    if (fx_id != nil)
      id = fx_id + FXL::CONTROLLER_SUFFIX;
      controller = fxmlLoader.getController();

      namespace.put(id, controller);

      if (parentLoader.controller != nil)
        field = getControllerFields().get(id);

        if (field != nil)
          begin
            field.set(parentLoader.controller, controller);
          rescue IllegalAccessException => exception
            raise LoadException.new(exception);
          end
        end
      end
    end

    return value;
  end
end

# Element representing a reference
class ReferenceElement < ValueElement
  attr_accessor :source
  @source = nil;

  def processAttribute(prefix, localName, value)
dputs callz + "processing attrib"
dp prefix, localName, value
    if (prefix == nil)
      if (localName == (FXL::REFERENCE_SOURCE_ATTRIBUTE))
        if (loadListener != nil)
          loadListener.readInternalAttribute(localName, value);
        end
        dputs callz + "SAVING SOURCES"
        @source = value;
      else
        super(prefix, localName, value);
      end
    else
      super(prefix, localName, value);
    end
  end

  def constructValue()
    if (source == nil)
      raise LoadException.new(FXL::REFERENCE_SOURCE_ATTRIBUTE + " is required.");
    end

    path = KeyPath.parse(source);
    if (!Expression.isDefined(parentLoader.namespace, path))
      raise LoadException.new("Value \"" + source + "\" does not exist.");
    end

    return Expression.get(parentLoader.namespace, path);
  end
end

# Element representing a copy
class CopyElement < ValueElement
  attr_accessor :source
  @source = nil;

  def processAttribute(prefix,  localName,  value)

    if (prefix == nil)
      if (localName == (FXL::COPY_SOURCE_ATTRIBUTE))
        if (loadListener != nil)
          loadListener.readInternalAttribute(localName, value);
        end

        @source = value;
      else
        super(prefix, localName, value);
      end
    else
      super(prefix, localName, value);
    end
  end

  def constructValue()
    if (source == nil)
      raise LoadException.new(FXL::COPY_SOURCE_ATTRIBUTE + " is required.");
    end

    path = KeyPath.parse(source);
    if (!Expression.isDefined(namespace, path))
      raise LoadException.new("Value \"" + source + "\" does not exist.");
    end

    sourceValue = Expression.get(namespace, path);
    sourceValueType = sourceValue.java_class();

    constructor = nil;
    begin
      constructor = ConstructorUtil.getConstructor(sourceValueType, [sourceValueType]);
    rescue NoSuchMethodException => exception
      # No-op
    end

    value=nil
    if (constructor != nil)
      begin
        #TODO: try to do evil things here
        ReflectUtil.checkPackageAccess(sourceValueType);
        value = constructor.newInstance(sourceValue);
      rescue InstantiationException => exception
        raise LoadException.new(exception);
      rescue IllegalAccessException => exception
        raise LoadException.new(exception);
      rescue InvocationTargetException => exception
        raise LoadException.new(exception);
      end
    else
      raise LoadException.new("Can't copy value " + sourceValue + ".");
    end

    return value;
  end
end

# Element representing a predefined root value
class RootElement < ValueElement
  @type = nil

  def processAttribute( prefix,  localName,  value)

    if (prefix == nil)
      if (localName == (FXL::ROOT_TYPE_ATTRIBUTE))
        if (loadListener != nil)
          loadListener.readInternalAttribute(localName, value);
        end

        @type = value;
      else
        super(prefix, localName, value);
      end
    else
      super(prefix, localName, value);
    end
  end

  def constructValue()
    if (@type == nil)
      raise LoadException.new(FXL::ROOT_TYPE_ATTRIBUTE + " is required.");
    end

    type = parentLoader.getType(@type);

    if (type == nil)
      raise LoadException.new(@type + " is not a valid type.");
    end

    value=nil
    root = parentLoader.root
    if (root == nil)
      raise LoadException.new("Root hasn't been set. Use method setRoot() before load.");
    else
      if (!type.isAssignableFrom(root.java_class()))
        raise LoadException.new("Root is not an instance of "										+ type.getName() + ".");
      end

      value = root;
    end

    return value;
  end
end

# Element representing a property
class PropertyElement < Element
  attr_accessor :name, :sourceType, :readOnly

  def initialize(current, xmlStreamReader, loadListener, parentLoader, name,  sourceType)

    @name = nil
    @sourceType = nil
    @readOnly = nil
    super(current, xmlStreamReader, loadListener, parentLoader)
    dputs (callz) + "Property Elt"
    dputs callz + name
    dprint callz
    dp sourceType
    if (parent == nil)
      raise LoadException.new("Invalid root element.");
    end

    if (parent.value == nil)
      raise LoadException.new("Parent element does not support property elements.");
    end

    @name = name;
    @sourceType = sourceType;

    if (sourceType == nil)
      # The element represents an instance property
      if (name.start_with?(FXL::EVENT_HANDLER_PREFIX))
        raise LoadException.new("\"" + name + "\" is not a valid element name.");
      end

      parentProperties = parent.getProperties();
      if (parent.isTyped())
        dputs (callz) +"it be typed"
        @readOnly = parent.getValueAdapter().read_only?(name);
      else
        dputs (callz) +"it be chedrk"
        # If the map already defines a value for the property, assume
        # that it is read-only
        @readOnly = parentProperties.has_key?(name);
      end

      if (@readOnly)
        value = parentProperties[name]
        if (value == nil)
          raise LoadException.new("Invalid property.");
        end
        dputs (callz) +"saving property #{name} => #{value}"
        updateValue(value);
      end
      dputs (callz) +"doneish"
    else
      dputs (callz) +"ITS READ OHLY"
      # The element represents a static property
      @readOnly = false;
    end
  end

  def isCollection()
    return (@readOnly) ? super() : false;
  end

  def add( element)
    dputs ( callz) +"Adding #{element} to ===> #{name}"
    dprint callz
    dp element
    dp element.class
    dp element.java_class
    if element.class.inspect == "Java::JavaNet::URL"
      # element = element.java_object
    end
    # Coerce the element to the list item type
    if (parent.isTyped())
      listType = parent.getValueAdapter().getGenericType(name);
      dputs callz + "Typed and list type is #{listType}"
      lit = RubyWrapperBeanAdapter.getListItemType(listType)
# FIXME: HACK!
    if element.class.inspect == "Java::JavaNet::URL"
      lit = Java::java.lang.String.java_class
    end

      element = RubyWrapperBeanAdapter.coerce(element, lit);
    end

    # Add the item to the list
    super(element);
  end

  def set( value)
    dputs (callz) +"setting prope value #{name} ==> #{value}"
    # Update the value
    updateValue(value);

    if (sourceType == nil)
      # Apply value to parent element's properties
      parent.getProperties[name] = value
    else
      if (parent.value.is_a? Builder)
        # Defer evaluation of the property
        parent.staticPropertyElements.add(self);
      else
        # Apply the static property value
        RubyWrapperBeanAdapter.put3(parent.value, sourceType, name, value);
      end
    end
  end

  def processAttribute( prefix,  localName,  value)
dputs (callz) +"processing #{prefix}, #{localName}, #{value} for #{name}"
    if (!readOnly)
      raise LoadException.new("Attributes are not supported for writable property elements.");
    end

    super(prefix, localName, value);
  end

  def processEndElement()
    super();
dputs (callz) +"ENDENDLT "
    if (readOnly)
      processInstancePropertyAttributes();
      processEventHandlerAttributes();
    end
  end

  def processCharacters()
    if (!readOnly)
      text = xmlStreamReader.getText();
      dputs (callz) +"whitlespa"
      #TODO: normal regexes
      text = extraneousWhitespacePattern.matcher(text).replaceAll(" ");

      set(text.strip());
    else
      super();
    end
  end
end

# Element representing an unknown static property
class UnknownStaticPropertyElement < Element
  def initialize
    if (parent == nil)
      raise LoadException.new("Invalid root element.");
    end

    if (parent.value == nil)
      raise LoadException.new("Parent element does not support property elements.");
    end
  end

  def isCollection()
    return false;
  end

  def set( value)
    updateValue(value);
  end

  def processCharacters()
    text = xmlStreamReader.getText();
    # TODO: REGEX!
    text = extraneousWhitespacePattern.matcher(text).replaceAll(" ");

    updateValue(text.strip());
  end
end

# Element representing a script block
#	class ScriptElement < Element
#    # TODO:  fix
#		 @source = nil;
#		@charset = parentLoader.charset;
#
#		def isCollection()
#			return false;
#		end

#		def processStartElement()
#			super();
#
#			if (source != nil && !staticLoad)
#				int i = source.rindex(".");
#				if (i == -1)
#					raise LoadException.new("Cannot determine type of script \""											+ source + "\".");
#				end
#
#				extension = source[(i + 1)..-1];
#				scriptEngine = nil
#        #TODO: use JRUBY stuff
#				oldLoader = Thread.currentThread().getContextClassLoader();
#				begin
#					Thread.currentThread().setContextClassLoader(classLoader);
#					scriptEngineManager = getScriptEngineManager();
#					scriptEngine = scriptEngineManager.getEngineByExtension(extension);
#        ensure
#					Thread.currentThread().setContextClassLoader(oldLoader);
#				end
#
#				if (scriptEngine == nil)
#					raise LoadException.new("Unable to locate scripting engine for"											+ " extension " + extension + ".");
#				end
#
#				scriptEngine.setBindings(scriptEngineManager.getBindings(), ScriptContext.ENGINE_SCOPE);
#
#				begin
#					location = nil
#					if (source[0] == '/')
#						location = classLoader.getResource(source[(1)..-1]);
#					else
#						if (parentLoader.location == nil)
#							raise LoadException.new("Base location is undefined.");
#						end
#
#						location = URL.new(parentLoader.location, source);
#					end
#
#					InputStreamReader scriptReader = nil;
#					begin
#						scriptReader = InputStreamReader.new(location.openStream(), charset);
#						scriptEngine.eval(scriptReader);
#					rescue ScriptException => exception
#						exception.printStackTrace();
#					end
#					finally
#						if (scriptReader != nil)
#							scriptReader.close();
#						end
#					end
#				rescue IOException => exception
#					raise LoadException.new(exception);
#				end
#			end
#		end
#
#		def processEndElement()
#			super();
#
#			if (value != nil && !staticLoad)
#				# Evaluate the script
#				begin
#					scriptEngine.eval((String) value);
#				rescue ScriptException => exception
#					System.err.println(exception.getMessage());
#				end
#			end
#		end
#
#		def processCharacters()
#			if (source != nil)
#				raise LoadException.new("Script source already specified.");
#			end
#
#			if (scriptEngine == nil && !staticLoad)
#				raise LoadException.new("Page language not specified.");
#			end
#
#			updateValue(xmlStreamReader.getText());
#		end
#
#		def processAttribute(String prefix, String localName, String value)
#
#			if (prefix == nil
#				&& localName == (FXL::SCRIPT_SOURCE_ATTRIBUTE))
#				if (loadListener != nil)
#					loadListener.readInternalAttribute(localName, value);
#				end
#
#				source = value;
#			elsif (localName == (FXL::SCRIPT_CHARSET_ATTRIBUTE))
#				if (loadListener != nil)
#					loadListener.readInternalAttribute(localName, value);
#				end
#
#				charset = Charset.forName(value);
#			else
#				raise LoadException.new(prefix == nil ? localName : prefix + ":" + localName
#																	 + " is not a valid attribute.");
#			end
#		end
#	end

# Element representing a define block
class DefineElement < Element
  def isCollection()
    return true;
  end

  def add(element)
    # No-op
  end

  def processAttribute(prefix, localName, value)
    raise LoadException.new("Element does not support attributes.");
  end
end