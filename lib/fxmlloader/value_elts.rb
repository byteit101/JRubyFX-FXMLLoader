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
    super

    # Build the value, if necessary
    if (value.is_a? Builder)
      updateValue(value.build());
      processValue();
    else
      processInstancePropertyAttributes();
    end
    processEventHandlerAttributes();
    # Process static property attributes
    if (staticPropertyAttributes.length > 0)
      for attribute in staticPropertyAttributes
        processPropertyAttribute(attribute);
      end
    end
    # Process static property elements
    if (staticPropertyElements.length > 0)
      for  element in staticPropertyElements
        RubyWrapperBeanAdapter.put(value, element.sourceType, element.name, element.value);
      end
    end

    rnest -1
    rputs value, ((rfx_id(value) && rfx_id_set?(value)) || rno_show?(value) ? ""  : "end")
    if (parent != nil)
      if (parent.isCollection())
        parent.add(value);
      else
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
        nsVersion = defaultNSURI[(defaultNSURI.rindex("/") + 1)..-1]
        jfx_version = if defined? FXL::JAVAFX_VERSION
          FXL::JAVAFX_VERSION
        else
          "http://javafx.com/javafx/2.2"
        end
        if (parentLoader.compareJFXVersions(jfx_version, nsVersion) < 0)
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
          properties[idProperty.value()]= @fx_id;
        end
      end
      rputs value, "__local_fx_id_setter.call(#{@fx_id.inspect}, self)"
      rfx_id value, @fx_id
      # Set the controller field value
      if (parentLoader.controller != nil)
        field = parentLoader.controller.instance_variable_set("@" + @fx_id, value)
      end
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
        @fx_id = value;

      elsif (localName == (FXL::FX_CONTROLLER_ATTRIBUTE))
        if (parentLoader.current.parent != nil)
          raise LoadException.new(FXL::FX_NAMESPACE_PREFIX + ":" + FXL::FX_CONTROLLER_ATTRIBUTE		+ " can only be applied to root element.");
        end

        if (parentLoader.controller != nil)
          raise LoadException.new("Controller value already specified.");
        end

        if (!staticLoad)
          type = nil
          begin
            type = value.constantize_by
          rescue ClassNotFoundException => exception
            raise LoadException.new(exception);
          end

          begin
            if (parentLoader.controllerFactory == nil)
              # TODO: does this work?
              parentLoader.controller = type.new
            else
              parentLoder.controller = (parentLoader.controllerFactory.call(type));
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
      super(prefix, localName, value);
    end
  end

end