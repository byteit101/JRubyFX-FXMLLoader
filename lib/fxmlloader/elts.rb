class JavaProxy
  def default_property
		self.java_class.getAnnotation(DefaultProperty.java_class);
  end
end

class Element
  attr_accessor :parent, :lineNumber, :current, :xmlStreamReader, :loadListener, :parentLoader
  attr_accessor :value, :valueAdapter, :eventHandlerAttributes, :instancePropertyAttributes, :staticPropertyAttributes, :staticPropertyElements
  def initialize(current, xmlStreamReader, loadListener, parentLoader)
    @parent = current;
    @lineNumber = xmlStreamReader.getLocation().getLineNumber();
    @current = current;
    @xmlStreamReader = xmlStreamReader
    @loadListener = loadListener
    @value = nil
    @valueAdapter = nil
    @eventHandlerAttributes = []
    @instancePropertyAttributes = []
    @staticPropertyAttributes = []
    @staticPropertyElements = []
    @parentLoader = parentLoader
  end
  def staticLoad
    @parentLoader.staticLoad
  end
  def callz
    numz = 1
    pppn = @parent
    while pppn
      numz+=1
      pppn = pppn.parent
    end
    (" " * numz) + @lineNumber.to_s + ": "
  end

  def isCollection()
    # Return true if value is a list, or if the value's type defines
    # a default property that is a list
    collection = false
    if (@value.kind_of?(Enumerable) || @value.java_kind_of?(Java.java.util.List))
      collection = true;
    else
      defaultProperty = @value.java_class.annotation(DefaultProperty.java_class);

      if (defaultProperty != nil)
        collection = getProperties()[defaultProperty.value].java_kind_of?(Java.java.util.List)
      else
        collection = false;
      end
    end
    return collection;
  end

  def add(element, prop_name=nil, rputs_elt=nil)
    # If value is a list, add element to it; otherwise, get the value
    # of the default property, which is assumed to be a list and add
    # to that (coerce to the appropriate type)
    if (@value.kind_of?(Enumerable) || @value.java_kind_of?(java.util.List))
      if prop_name == nil
        rputs value, "add(#{rget(element)||element.inspect})"
      else
        rputs @parent.value, "get#{prop_name[0].upcase}#{prop_name[1..-1]}.add(#{rputs_elt || rget(element)||element.inspect})"
      end
      value.to_java
    else
      type = value.java_class
      defaultProperty = type.annotation(DefaultProperty.java_class);
      defaultPropertyName = defaultProperty.to_java.value();

      # Get the list value
      list =  getProperties[defaultPropertyName]

      # Coerce the element to the list item type
      if (!java.util.Map.java_class.assignable_from?(type))
        listType = @valueAdapter.getGenericType(defaultPropertyName);
        element = RubyWrapperBeanAdapter.coerce(element, RubyWrapperBeanAdapter.getListItemType(listType));
      end
      rputs @value, "get#{defaultPropertyName[0].upcase}#{defaultPropertyName[1..-1]}.add(#{rget(element)||element.inspect})"
      list = list.to_java if list.class == Java::JavaObject
      list
    end.add(element)
  end

  def set(value)
    unless @value
      raise LoadException.new("Cannot set value on this element.");
    end

    # Apply value to this element's properties
    type = @value.java_class;
    defaultProperty = type.getAnnotation(DefaultProperty.java_class);
    if (defaultProperty == nil)
      raise LoadException.new("Element does not define a default property.");
    end

    getProperties[defaultProperty.value] = value
  end

  def updateValue(value)
    @value = value;
    @valueAdapter = nil;
  end

  def isTyped()
    !(@value.java_kind_of? Java::java.util.Map or @value.is_a? Hash  )
  end

  def getValueAdapter()
    if (@valueAdapter == nil)
      @valueAdapter = RubyWrapperBeanAdapter.for(@value)
    end
    return @valueAdapter;
  end

  def getProperties()
    return (isTyped()) ? getValueAdapter() : @value;
  end

  def processStartElement()
    n = @xmlStreamReader.getAttributeCount()
    n.times do |i|
      prefix = @xmlStreamReader.getAttributePrefix(i);
      localName = @xmlStreamReader.getAttributeLocalName(i);
      value = @xmlStreamReader.getAttributeValue(i);

      if (@loadListener && prefix && prefix == (FXL::FX_NAMESPACE_PREFIX))
        @loadListener.readInternalAttribute(prefix + ":" + localName, value);
      end

      processAttribute(prefix, localName, value);
    end
  end

  def processEndElement()
    # No-op
  end

  def processCharacters()
    raise LoadException.new("Unexpected characters in input stream.");
  end

  def processInstancePropertyAttributes()
    if (@instancePropertyAttributes.length > 0)
      for attribute in @instancePropertyAttributes
        processPropertyAttribute(attribute);
      end
    end
  end

  def processAttribute(prefix, localName, value)
    if (prefix == nil)
      # Add the attribute to the appropriate list
      if (localName.start_with?(FXL::EVENT_HANDLER_PREFIX))
        if (@loadListener != nil)
          @loadListener.readEventHandlerAttribute(localName, value);
        end
        eventHandlerAttributes <<(Attribute.new(localName, nil, value));
      else
        i = localName.rindex('.');

        if (i == nil)
          # The attribute represents an instance property
          if (@loadListener != nil)
            @loadListener.readPropertyAttribute(localName, nil, value);
          end

          instancePropertyAttributes << (Attribute.new(localName, nil, value));
        else
          # The attribute represents a static property
          name = localName[(i + 1)..-1];
          sourceType = parentLoader.getType(localName[0, i]);

          if (sourceType != nil)
            if (@loadListener != nil)
              @loadListener.readPropertyAttribute(name, sourceType, value);
            end

            @staticPropertyAttributes << (Attribute.new(name, sourceType, value));
          elsif (staticLoad)
            if (@loadListener != nil)
              @loadListener.readUnknownStaticPropertyAttribute(localName, value);
            end
          else
            raise LoadException.new(localName + " is not a valid attribute.");
          end
        end

      end
    else
      raise LoadException.new(prefix + ":" + localName +
          " is not a valid attribute.");
    end
  end

  def processPropertyAttribute(attribute)
    value = attribute.value;
    if (isBindingExpression(value))
      # Resolve the expression

      if (attribute.sourceType != nil)
        raise LoadException.new("Cannot bind to static property.");
      end

      if (!isTyped())
        raise LoadException.new("Cannot bind to untyped object.");
      end

      # TODO We may want to identify binding properties in processAttribute()
      # and apply them after build() has been called
      if (@value.is_a? Builder)
        raise LoadException.new("Cannot bind to builder property.");
      end

      value = value[2..-2]    # TODO: BINDING_EXPRESSION_PREFIX == ${
      #value.length() - 1];
      # TODO: this only works for 7, not 8
      expression = Expression.valueOf(value);
      # Create the binding
      targetAdapter = RubyWrapperBeanAdapter.new(@value);
      propertyModel = targetAdapter.getPropertyModel(attribute.name).to_java
      type = targetAdapter.getType(attribute.name);
      if (propertyModel.is_a? Property)
        rputs @value, "#{attribute.name}Property.bind(RRExpressionValue.new(__local_namespace, Java::org.jruby.jfx8.Expression.valueOf(#{value.inspect}), Java::#{type.name.gsub(/[\$\.]/, "::")}.java_class))"
        #expression.value_property.addListener(JRExpressionTargetMapping.new(expression, getProperties(), Expression.split(value)));
        ( propertyModel).bind(RRExpressionValue.new(parentLoader.namespace, expression, type));
      end
    elsif (isBidirectionalBindingExpression(value))
      raise UnsupportedOperationException.new("This feature is not currently enabled.");
    else
      processValue3(attribute.sourceType, attribute.name, value);
    end
  end

  def isBindingExpression(aValue)
    # TODO: BINDING_EXPRESSION_PREFIX == ${
    aValue.start_with?("${") && aValue.end_with?(FXL::BINDING_EXPRESSION_SUFFIX);
  end

  def isBidirectionalBindingExpression(aValue)
    return aValue.start_with?(FXL::BI_DIRECTIONAL_BINDING_PREFIX);
  end

  def processValue3( sourceType,  propertyName,  aValue)


    processed = false;
    #process list or array first
    if (sourceType == nil && isTyped())
      lvalueAdapter = getValueAdapter();
      type = lvalueAdapter.getType(propertyName);

      if (type == nil)
        dputs "Processing values3 fails on: "
        dp sourceType, propertyName, aValue
        dp lvalueAdapter
        dp caller
        raise("Property \"" + propertyName          + "\" does not exist" + " or is read-only.");
      end
      if (List.java_class.assignable_from?(type) && lvalueAdapter.read_only?(propertyName))
        populateListFromString(lvalueAdapter, propertyName, aValue);
        processed = true;
      elsif false #TODO: fix type.ruby_class.ancestors.include? Enumerable
        applyProperty(propertyName, sourceType, populateArrayFromString(type, aValue));
        processed = true;
      end
    end
    if (!processed)
      applyProperty(propertyName, sourceType, resolvePrefixedValue(aValue));
      processed = true;
    end
    return processed;
  end


  # Resolves value prefixed with RELATIVE_PATH_PREFIX and
  # RESOURCE_KEY_PREFIX.

  def resolvePrefixedValue(aValue)
    if (aValue.start_with?(FXL::ESCAPE_PREFIX))
      aValue = aValue[FXL::ESCAPE_PREFIX.length..-1]

      if (aValue.length == 0 || !(aValue.start_with?(FXL::ESCAPE_PREFIX) ||
              aValue.start_with?(FXL::RELATIVE_PATH_PREFIX) ||
              aValue.start_with?(FXL::RESOURCE_KEY_PREFIX) ||
              aValue.start_with?(FXL::EXPRESSION_PREFIX) ||
              aValue.start_with?(FXL::BI_DIRECTIONAL_BINDING_PREFIX)))
        raise LoadException.new("Invalid escape sequence.");
      end
      return aValue;
    elsif (aValue.start_with?(FXL::RELATIVE_PATH_PREFIX))
      aValue = aValue[FXL::RELATIVE_PATH_PREFIX.length..-1]
      if (aValue.length == 0)
        raise LoadException.new("Missing relative path.");
      end
      if (aValue.start_with?(FXL::RELATIVE_PATH_PREFIX))
        # The prefix was escaped
        warnDeprecatedEscapeSequence(RELATIVE_PATH_PREFIX);
        return aValue;
      else
        begin
          if $JRUBYFX_AOT_COMPILING
            return RelativeFXMLString.new(aValue, URL.new(parentLoader.location, aValue).to_s)
          else
            return (aValue[0] == '/') ? classLoader.getResource(aValue[1..-1]).to_s : URL.new(parentLoader.location, aValue).to_s
          end
        rescue MalformedURLException => e
          dp e
          dputs "#{parentLoader.location} + /+ #{aValue}"
          raise "whoops"
        end
      end
    elsif (aValue.start_with?(FXL::RESOURCE_KEY_PREFIX))
      aValue = aValue[FXL::RESOURCE_KEY_PREFIX.length..-1]
      if (aValue.length() == 0)
        raise LoadException.new("Missing resource key.");
      end
      if (aValue.start_with?(FXL::RESOURCE_KEY_PREFIX))
        # The prefix was escaped
        warnDeprecatedEscapeSequence(FXL::RESOURCE_KEY_PREFIX);
        return aValue;
      else
        # Resolve the resource value
        if (@resources == nil)
          raise LoadException.new("No resources specified.");
        end
        if (!@resources.has_key?(aValue))
          raise LoadException.new("Resource \"" + aValue + "\" not found.");
        end
        return @resources.getString(aValue);
      end
    elsif (aValue.start_with?(FXL::EXPRESSION_PREFIX))
      aValue = aValue[FXL::EXPRESSION_PREFIX.length..-1]
      if (aValue.length() == 0)
        raise LoadException.new("Missing expression.");
      end
      if (aValue.start_with?(FXL::EXPRESSION_PREFIX))
        # The prefix was escaped
        warnDeprecatedEscapeSequence(FXL::EXPRESSION_PREFIX);
        return aValue;
      elsif (aValue == (FXL::NULL_KEYWORD))
        # The attribute value is nil
        return nil;
      end
      # remove all nils, them add one in at the end so [0] returns nil if empty
      q = (KeyPath.parse(aValue).map{|i|parentLoader.namespace[i]} - [nil] + [nil])[0]
      return q
    end
    return aValue;
  end

=begin
 * Creates an array of given type and populates it with values from a
 * string where tokens are separated by ARRAY_COMPONENT_DELIMITER. If
 * token is prefixed with RELATIVE_PATH_PREFIX a value added to the
 * array becomes relative to document location.
=end
  #TODO: fix this udp to use java arrays
  def populateArrayFromString( type, stringValue)

    propertyValue = nil;
    # Split the string and set the values as an array
    componentType = type.getComponentType();

    if (stringValue.length > 0)
      values = stringValue.split(FXL::ARRAY_COMPONENT_DELIMITER);
      propertyValue = Array.newInstance(componentType, values.length);
      values.length.times do |i|
        Array.set(propertyValue, i,
          RubyWrapperBeanAdapter.coerce(resolvePrefixedValue(values[i].strip),
            type.getComponentType()));
      end
    else
      propertyValue = Array.newInstance(componentType, 0);
    end
    return propertyValue;
  end

=begin
		 * Populates list with values from a string where tokens are separated
		 * by ARRAY_COMPONENT_DELIMITER. If token is prefixed with
		 * RELATIVE_PATH_PREFIX a value added to the list becomes relative to
		 * document location.
=end
  #TODO: check the types
  def populateListFromString( valueAdapter, listPropertyName,stringValue)
    # Split the string and add the values to the list
    list =  valueAdapter[listPropertyName].to_java
    listType = valueAdapter.getGenericType(listPropertyName);
    itemType =  RubyWrapperBeanAdapter.getGenericListItemType(listType);

    if (itemType.is_a? ParameterizedType)
      itemType = ( itemType).getRawType();
    end

    if (stringValue.length() > 0)
      values = stringValue.split(FXL::ARRAY_COMPONENT_DELIMITER)

      for  aValue in values
        aValue = aValue.strip
        list.add(
          RubyWrapperBeanAdapter.coerce(resolvePrefixedValue(aValue),
            itemType));
      end
    end
  end

  def warnDeprecatedEscapeSequence(prefix)
    puts(prefix + prefix + " is a deprecated escape sequence. "       + "Please use \\" + prefix + " instead.");
  end

  def applyProperty(name,  sourceType, value)
    if (sourceType == nil)
      getProperties[name] = value
    else
      RubyWrapperBeanAdapter.put3(@value, sourceType, name, value);
    end
  end

  def processEventHandlerAttributes()
    if (@eventHandlerAttributes.length > 0 && !parentLoader.staticLoad)
      for attribute in @eventHandlerAttributes
        eventHandler = nil;
        attrValue = attribute.value;

        if (attrValue.start_with?(FXL::CONTROLLER_METHOD_PREFIX))
          attrValue = attrValue[FXL::CONTROLLER_METHOD_PREFIX.length..-1]
          if (!attrValue.start_with?(FXL::CONTROLLER_METHOD_PREFIX))
            if (attrValue.length() == 0)
              raise LoadException.new("Missing controller method.");
            end
            if (parentLoader.controller == nil)
              dputs "eek"
              raise LoadException.new("No controller specified. ");
            end

            #            method = parentLoader.controller.method(attrValue)
            #
            #            if (method == nil)
            #              raise LoadException.new("Controller method \"" + attrValue + "\" not found.");
            #            end
            eventHandler = EventHandlerWrapper.new(parentLoader.controller, attrValue)
          end

        elsif (attrValue.start_with?(FXL::EXPRESSION_PREFIX))
          attrValue = attrValue[FXL::EXPRESSION_PREFIX.length..-1]
          if (attrValue.length() == 0)
            raise LoadException.new("Missing expression reference.");
          end
          expression = Expression.get(@namespace, KeyPath.parse(attrValue));
          if (expression.is_a? EventHandler)
            eventHandler = expression;
          end

        end
        if (eventHandler == nil)
          if (attrValue.length() == 0 || parentLoader.scriptEngine == nil)
            raise LoadException.new("Error resolving " + attribute.name + "='" + attribute.value +
                "', either the event handler is not in the Namespace or there is an error in the script.");
          end

          eventHandler = ScriptEventHandler.new(attrValue, parentLoader.scriptEngine);
        end
        # Add the handler
        if (eventHandler != nil)

          addEventHandler(attribute, eventHandler);
        end
      end
    end
  end

  def addEventHandler(attribute, eventHandler)
    if (attribute.name.end_with?(FXL::CHANGE_EVENT_HANDLER_SUFFIX))
      i = FXL::EVENT_HANDLER_PREFIX.length();
      j = attribute.name.length() - FXL::CHANGE_EVENT_HANDLER_SUFFIX.length();
      if (i == j)
        if (@value.is_a? ObservableList)
          list =  @value;
          list.addListener(ObservableListChangeAdapter.new(list, eventHandler));
        elsif (@value.is_a? ObservableMap)
          map = @value;
          map.addListener(ObservableMapChangeAdapter.new(map, eventHandler));
        else
          raise LoadException.new("Invalid event source.");
        end
      else
        key = attribute.name[i].downcase + attribute.name[i + 1, j]
        propertyModel = getValueAdapter().getPropertyModel(key);
        if (propertyModel == nil)
          raise LoadException.new(@value.getClass().getName() + " does not define" + " a property model for \"" + key + "\".");
        end

        propertyModel.addListener(PropertyChangeAdapter.new(@value,  eventHandler));
      end
    else
      getValueAdapter[attribute.name] =  eventHandler
    end
  end
end

class Attribute
  attr_accessor :name, :sourceType, :value
  def initialize( paramString1,paramClass,  paramString2)
    @name = paramString1;
    @sourceType = paramClass;
    @value = paramString2;
  end
end

class EventHandlerWrapper
  include EventHandler
  attr_reader :funcName
  def initialize(ctrl, funcName)
    @ctrl = ctrl
    @funcName = funcName
  end
  def handle(eventArgs)
    if @ctrl.respond_to? @funcName
      if @ctrl.method(@funcName).arity == 0
        @ctrl.send(@funcName)
      else
        @ctrl.send(@funcName, eventArgs)
      end
    else
      puts "Warning: method #{@funcName} was not found on controller #{@ctrl}"
    end
  end
end

class ScriptEventHandler
  include EventHandler
  attr_reader :script, :scriptEngine
  def initialize(script, scriptEngine)
    @script = script;
    @scriptEngine = scriptEngine;
  end

  def handle(event)
    # Don't pollute the page namespace with values defined in the script
    engineBindings = @scriptEngine.getBindings(ScriptContext::ENGINE_SCOPE);
    #localBindings = @scriptEngine.createBindings(); # TODO: this causes errors with nashorn in jdk8 by creating a different kind of 
    # script object that doesn't respect the magic nashorn.global object
    localBindings = Java::JavaxScript::SimpleBindings.new
    localBindings.put_all(engineBindings)
    localBindings.put(FXL::EVENT_KEY, event);
    @scriptEngine.setBindings(localBindings, ScriptContext::ENGINE_SCOPE);

    # Execute the script
    begin
      @scriptEngine.eval(@script);
    rescue ScriptException => exception
      raise exception
    end

    # Restore the original bindings
    @scriptEngine.setBindings(engineBindings, ScriptContext::ENGINE_SCOPE);
  end
end

class RelativeFXMLString < String
  alias :super_inspect :inspect
  def initialize(str, rel)
    super(rel)
    @rel = str
  end
  def inspect
    "java.net.URL.new(__local_namespace['location'], #{@rel.inspect}).to_s"
  end
  def to_s
    super
  end
  def class()
    String
  end
end
