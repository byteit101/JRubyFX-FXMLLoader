require_relative './elts'

class StupidFixTODOInsets < Java::javafx::geometry::InsetsBuilder
  def initialize()
    super
  end
  add_method_signature :getLeft, [Java::double]
  def getLeft()

  end

  add_method_signature :setLeft, [Java::java.lang.Void, Java::double]
  def setLeft(value)
    left(value)
  end

  add_method_signature :getRight, [Java::double]
  def getRight()

  end

  add_method_signature :setRight, [Java::java.lang.Void, Java::double]
  def setRight(value)
    right(value)
  end
  add_method_signature :getBottom, [Java::double]
  def getBottom()

  end

  add_method_signature :setBottom, [Java::java.lang.Void, Java::double]
  def setBottom(value)
    bottom(value)
  end
  add_method_signature :getTop, [Java::double]
  def getTop()

  end

  add_method_signature :setTop, [Java::java.lang.Void, Java::double]
  def setTop(value)
    top(value)
  end

  def size
    puts "GAAAAAAAAAAAAAA!!!!!"
    puts caller
    990
  end
  def to_s
    "the thingabmabomb"
  end
  def inspect
    "whozamawhatzit"
  end
end

class ValueElement < Element
  attr_accessor :fx_id
  @fx_id = nil;
  def processStartElement
    super

    updateValue(constructValue());

    if (value.is_a? Builder)
      processInstancePropertyAttributes();
    else
      processValue();
    end
  end

  def processEndElement()
    puts callz + "process end super?"
    super
    puts callz + "process end superd!"
    p value

    # Build the value, if necessary
    if (value.is_a? Builder)
      puts "build it"
      updateValue(value.build());
puts "process it"
      processValue();
    else
      processInstancePropertyAttributes();
    end
puts "donet"
    processEventHandlerAttributes();
puts "ahndersAtrrs"
    # Process static property attributes
    if (staticPropertyAttributes.length > 0)
      for attribute in staticPropertyAttributes
        puts "process prop attr-----------"
        p attribute
        processPropertyAttribute(attribute);
      end
    end
puts "staticpro"
    # Process static property elements
    if (staticPropertyElements.length > 0)
      for  element in staticPropertyElements
        RubyWrapperBeanAdapter.put(value, element.sourceType, element.name, element.value);
      end
    end
puts "parentS>AS"
    if (parent != nil)
      if (parent.isCollection())
        parent.add(value);
      else
        puts callz + " ANd setting  #{value} on #{parent}"
        parent.set value
      end
    end
  end

  def getListValue( parent,  listPropertyName,  value)
    # If possible, coerce the value to the list item type
    if (parent.isTyped())
      listType = parent.getValueAdapter().getGenericType(listPropertyName);

      if (listType != nil)
        itemType = RubyWrapperBeanAdapter.getGenericListItemType(listType);

        if (itemType.is_a? ParameterizedType)
          itemType = (itemType).getRawType();
        end

        value = RubyWrapperBeanAdapter.coerce(value,itemType);
      end
    end

    return value;
  end

  def processValue()
    # If this is the root element, update the value
    if (parent == nil)
      root = value;

      # checking version of fx namespace - throw exception if not supported
      fxNSURI = xmlStreamReader.getNamespaceContext().getNamespaceURI("fx");
      if (fxNSURI != nil)
        fxVersion = fxNSURI[(fxNSURI.rindex("/") + 1)..-1];
        if (parentLoader.compareJFXVersions(FxmlLoader::FX_NAMESPACE_VERSION, fxVersion) < 0)
          raise LoadException.new("Loading FXML document of version "	+ fxVersion + " by JavaFX runtime supporting version " + FxmlLoader::FX_NAMESPACE_VERSION);
        end
      end

      # checking the version JavaFX API - print warning if not supported
      defaultNSURI = xmlStreamReader.getNamespaceContext().getNamespaceURI("");
      if (defaultNSURI != nil)
        nsVersion = defaultNSURI[(defaultNSURI.lastIndexOf("/") + 1)..-1]
        if (parentLoader.compareJFXVersions(FXL::JAVAFX_VERSION, nsVersion) < 0)
          Logging.getJavaFXLogger().warning("Loading FXML document with JavaFX API of version " + nsVersion + " by JavaFX runtime of version " + FXL::JAVAFX_VERSION);
        end
      end
    end

    # Add the value to the namespace
    if (@fx_id != nil)
      parentLoader.namespace[@fx_id] =  value

      # If the value defines an ID property, set it
      idProperty = value.java_class.annotation(IDProperty.java_class);

      if (idProperty != nil)
        properties = getProperties();
        # set fx:id property value to Node.id only if Node.id was not
        # already set when processing start element attributes
        if (properties[idProperty.value] == nil)
          puts callz + "saving ID property"
          properties[idProperty.value()]= @fx_id;
        end
      end
      puts callz+ "About to set instance variable #{@fx_id}"
      # Set the controller field value
      if (parentLoader.controller != nil)
        field = parentLoader.controller.instance_variable_set("@" + @fx_id, value)
      end
      puts callz + "Set.."
    end
  end

  def processCharacters()
    type = value.java_class
    defaultProperty = type.getAnnotation(DefaultProperty.java_class);

    # If the default property is a read-only list, add the value to it;
    # otherwise, set the value as the default property
    if (defaultProperty != nil)
      text = xmlStreamReader.getText();
      #TODO: FIX
      text = extraneousWhitespacePattern.matcher(text).replaceAll(" ");

      defaultPropertyName = defaultProperty.value();
      valueAdapter = getValueAdapter();

      if (valueAdapter.read_only?(defaultPropertyName) && List.class.isAssignableFrom(valueAdapter.getType(defaultPropertyName)))
        list = valueAdapter.get(defaultPropertyName);
        list.add(getListValue(self, defaultPropertyName, text));
      else
        valueAdapter.put(defaultPropertyName, text.strip);
      end
    else
      throw LoadException.new(type.getName() + " does not have a default property.");
    end
  end

  def processAttribute( prefix,  localName,  value)
    if (prefix != nil				&& prefix == (FXL::FX_NAMESPACE_PREFIX))
      if (localName == (FXL::FX_ID_ATTRIBUTE))
        # Verify that ID is a valid identifier
        if (value == (FXL::NULL_KEYWORD))
          raise LoadException.new("Invalid identifier.");
        end
#
#        value.length.times do |i|
#          # TODO: FIX
#          if (!Java.java.lang.Character.java_send :isJavaIdentifierPart, [Java::char], value[i].to_java(:char))
#            raise LoadException.new("Invalid identifier.");
#          end
#        end
puts callz + "Found FXID is #{value}"
        @fx_id = value;

      elsif (localName == (FXL::FX_CONTROLLER_ATTRIBUTE))
        if (current.parent != nil)
          raise LoadException.new(FXL::FX_NAMESPACE_PREFIX + ":" + FXL::FX_CONTROLLER_ATTRIBUTE		+ " can only be applied to root element.");
        end

puts callz + "Found controller attrib is #{value} (#{controller}, #{staticLoad})"
        if (controller != nil)
          raise LoadException.new("Controller value already specified.");
        end

        if (!staticLoad)
          type = nil
          begin
            type = classLoader.loadClass(value);
          rescue ClassNotFoundException => exception
            raise LoadException.new(exception);
          end

          begin
            if (controllerFactory == nil)
              # TODO: does this work?
              setController(ReflectUtil.newInstance(type));
            else
              setController(controllerFactory.call(type));
            end
          rescue InstantiationException => exception
            raise LoadException.new(exception);
          rescue IllegalAccessException => exception
            raise LoadException.new(exception);
          end
        end
      else
        raise LoadException.new("Invalid attribute.");
      end
    else
      puts callz + "Super Again!"
      super(prefix, localName, value);
    end
  end

end