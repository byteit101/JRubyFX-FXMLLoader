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
    puts callz + "Is it a collection? #{collection.inspect} <= #{@value.java_class}"
    return collection;
  end

  def add(element)
    # If value is a list, add element to it; otherwise, get the value
    # of the default property, which is assumed to be a list and add
    # to that (coerce to the appropriate type)
    if (@value.kind_of?(Enumerable) || @value.java_kind_of?(java.util.List))
      value.to_java
    else
      type = value.java_class
      defaultProperty = type.annotation(DefaultProperty.java_class);
      defaultPropertyName = defaultProperty.to_java.value();

      # Get the list value
      list =  getProperties[defaultPropertyName]

      # Coerce the element to the list item type
      if (!Map.java_class.isAssignableFrom(type))
        listType = @valueAdapter.getGenericType(defaultPropertyName);
        element = RubyWrapperBeanAdapter.coerce(element, RubyWrapperBeanAdapter.getListItemType(listType));
      end
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
    puts callz + "Updating value from #{@value} to #{value.class}"
    @value = value;
    @valueAdapter = nil;
  end

  def isTyped()
    puts callz + "checking if typed"
    p @value.class
    p @value
    q =  !(@value.java_kind_of? Java::java.util.Map or @value.is_a? Hash  );
    puts callz + "type result: #{q.inspect}"
    q
  end

  def getValueAdapter()
    if (@valueAdapter == nil)
      puts callz + "trying to get itqq"
      print callz
      print @value
      puts @value.class
      puts caller
      if @value.class.to_s == "Java::JavafxFxml::ObjectBuilder"
        puts caller
      end
      @valueAdapter = RubyWrapperBeanAdapter.new(@value);
      puts callz + "got"
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

      if (@loadListener && prefix && prefix.equals(FXL::FX_NAMESPACE_PREFIX))
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
        puts callz + "found eventHandler prefix #{prefix}, #{localName}, #{value}"
        eventHandlerAttributes <<(Attribute.new(localName, nil, value));
      else
        i = localName.rindex('.');

        if (i == nil)
          # The attribute represents an instance property
          if (@loadListener != nil)
            @loadListener.readPropertyAttribute(localName, nil, value);
          end

        puts callz + "found property attrib #{prefix}, #{localName}, #{value}"
          instancePropertyAttributes << (Attribute.new(localName, nil, value));
        else
          # The attribute represents a static property
          name = localName[(i + 1)..-1];
          sourceType = parentLoader.getType(localName[0, i]);

        puts callz + "found static property #{prefix}, #{localName}, #{value}"
        puts callz + "and its #{sourceType}, #{@staticLoad}"
          if (sourceType != nil)
            if (@loadListener != nil)
              @loadListener.readPropertyAttribute(name, sourceType, value);
            end

            @staticPropertyAttributes << (Attribute.new(name, sourceType, value));
          elsif (@staticLoad)
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
      puts callz  + "is a binding !"
      # Resolve the expression
      expression= nil

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

      value = value[FXL::BINDING_EXPRESSION_PREFIX.length(),
        value.length() - 1];
      expression = Expression.valueOf(value);

      # Create the binding
      targetAdapter = RubyWrapperBeanAdapter.new(@value);
      propertyModel = targetAdapter.getPropertyModel(attribute.name);
      type = targetAdapter.getType(attribute.name);

      if (propertyModel.is_a? Property)
        ( propertyModel).bind(ExpressionValue.new(namespace, expression, type));
      end
    elsif (isBidirectionalBindingExpression(value))
      raise UnsupportedOperationException.new("This feature is not currently enabled.");
    else
      puts callz + "processing 3 for #{attribute.sourceType}, #{attribute.name}, #{value}"
      processValue3(attribute.sourceType, attribute.name, value);
    end
  end

  def isBindingExpression(aValue)
    return aValue.start_with?(FXL::BINDING_EXPRESSION_PREFIX) && aValue.end_with?(BINDING_EXPRESSION_SUFFIX);
  end

  def isBidirectionalBindingExpression(aValue)
    return aValue.start_with?(FXL::BI_DIRECTIONAL_BINDING_PREFIX);
  end

  def processValue3( sourceType,  propertyName,  aValue)


    processed = false;
    #process list or array first
    if (sourceType == nil && isTyped())
      puts callz + "getting value adptr"
      lvalueAdapter = getValueAdapter();
      type = lvalueAdapter.getType(propertyName);

      if (type == nil)
        puts "Processing values3 fails on: "
        p sourceType, propertyName, aValue
        p lvalueAdapter
        p caller
        raise PropertyNotFoundException.new("Property \"" + propertyName          + "\" does not exist" + " or is read-only.");
      end
      puts "checking assignable"
      if (List.java_class.assignable_from?(type.java_class) && lvalueAdapter.read_only?(propertyName))
        populateListFromString(lvalueAdapter, propertyName, aValue);
        processed = true;
      elsif (type.is_a? Enumerable)
        applyProperty(propertyName, sourceType, populateArrayFromString(type, aValue));
        processed = true;
      end
    end
    puts callz + "276"
    if (!processed)
      puts callz + "Must appky it"
      applyProperty(propertyName, sourceType, resolvePrefixedValue(aValue));
      puts callz + "280"
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
      aValue = aValue.substring[FXL::RELATIVE_PATH_PREFIX.length..-1]
      if (aValue.length == 0)
        raise LoadException.new("Missing relative path.");
      end
      if (aValue.start_with?(FXL::RELATIVE_PATH_PREFIX))
        # The prefix was escaped
        warnDeprecatedEscapeSequence(RELATIVE_PATH_PREFIX);
        return aValue;
      else
        begin
          return (aValue[0] == '/') ? classLoader.getResource(aValue[1..-1]).to_s : URL.new(@location, aValue).to_s
        rescue MalformedURLException => e
          puts (@location + "/" + aValue);
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
      return Expression.get(@namespace, KeyPath.parse(aValue));
    end
    return aValue;
  end

=begin
 * Creates an array of given type and populates it with values from a
 * string where tokens are separated by ARRAY_COMPONENT_DELIMITER. If
 * token is prefixed with RELATIVE_PATH_PREFIX a value added to the
 * array becomes relative to document location.
=end
  #TODO: fix this up to use java arrays
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
    list =  valueAdapter[listPropertyName]
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
              puts "eek"
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
          if (attrValue.length() == 0 || @scriptEngine == nil)
            raise LoadException.new("Error resolving " + attribute.name + "='" + attribute.value +
                "', either the event handler is not in the Namespace or there is an error in the script.");
          end

          eventHandler = ScriptEventHandler.new(attrValue, @scriptEngine);
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
  def initialize(ctrl, funcName)
    @ctrl = ctrl
    @funcName = funcName
  end
  def handle(eventArgs)
    begin
      if @ctrl.method(@funcName).arity > 0
        @ctrl.send(@funcName, eventArgs)
      else
        @ctrl.send(@funcName)
      end
    rescue NameError
      puts "Warning: method #{@funcName} was not found on controller #{@ctrl}"
    end
  end
end