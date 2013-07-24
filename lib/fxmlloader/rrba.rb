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

#/**
# * Exposes Java Bean properties of an object via the {@link Mapend interface.
# * A call to {@link Map#get(Object)end invokes the getter for the corresponding
# * property, and a call to {@link Map#put(Object, Object)end invokes the
# * property's setter. Appending a "Property" suffix to the key returns the
# * corresponding property model.
# */
class RubyWrapperBeanAdapter

  @@method_cache = {}

  GET_PREFIX = "get"
  IS_PREFIX = "is"
  SET_PREFIX = "set"
  PROPERTY_SUFFIX = "Property"

  VALUE_OF_METHOD_NAME = "valueOf"

  OBJECT_PUBLIC_METHODS = Object.new.public_methods

  #@param @bean
  #The Bean object to wrap.
  def initialize(bean)
    @bean = bean
    type = @bean.java_class
    javas = []
    while type != java.lang.Object.java_class && !@@method_cache.has_key?(type)
      javas += build_cache_for(type)
      type = type.superclass
    end
    #    class_methods = {}
    #    (@bean.public_methods - OBJECT_PUBLIC_METHODS - javas.map{|x|x.name.to_sym}).each do |method_name|
    #      puts "ruby method: #{method_name}"
    #      name = method_name.to_s
    #      unless class_methods.has_key? name
    #        class_methods[name] = []
    #      else
    #        class_methods[name]
    #      end << method_name.to_sym
    #    end
    #    @@method_cache[@bean.class] =
  end

  def build_cache_for(type)
    class_methods = {}

    ReflectUtil.checkPackageAccess(type) # TODO: do I want this ?

    java_methods = type.declared_instance_methods.each do |method|
      modifiers = method.modifiers
      if Modifier.public?(modifiers) && !Modifier.static?(modifiers)
        name = method.name
        unless class_methods.has_key? name
          class_methods[name] = []
        else
          class_methods[name]
        end << method
      end
    end

    @@method_cache[type] = class_methods
    return java_methods
  end

  def getMethod(name, *parameter_types)
    type = @bean.java_class
    while type != java.lang.Object.java_class
      if methods = (@@method_cache[type] || {})[name]
        methods.each do |method|
          return method if method.name == name && method.parameter_types == parameter_types
        end
      end
      type = type.superclass
    end
    return nil
  end

  def getter(key)
    capital = camelize(key)
    return getMethod(GET_PREFIX + capital) if @bean.respond_to?(GET_PREFIX + capital)
    return getMethod(IS_PREFIX + capital)
  end

  def setter(key)
    raise UnsupportedOperationException.new("Cannot determine type for property.") unless type = getType(key)
    return getMethod(method_name(SET_PREFIX, key), type)
  end

  def method_name(prefix, key)
    return prefix + camelize(key)
  end

  def camelize(key)
    key[0].upcase + key[1..-1]
  end

  def [](key)
    key = key.to_s
    begin
      unless key.end_with?(PROPERTY_SUFFIX)
        camel = camelize(key)
        unless !@bean.respond_to?(GET_PREFIX + camel) and @bean.respond_to?(IS_PREFIX + camel)
          @bean.send(GET_PREFIX + camel)
        else
          @bean.send(IS_PREFIX + camel)
        end
      else
        @bean.send key
      end
    rescue NoMethodError => nme
      raise unless nme.name.to_s.end_with?(key)
      puts "failing on #{key}"
      p @bean
      p @bean.class
      puts caller
      nil
    end
  end

  def []=(key, value)
    raise "NULL PTR" unless key

    setter = method_name(SET_PREFIX, key)

    raise "Property \"#{key}\" does not exist or is read-only." unless @bean.respond_to? setter
    ty = getType(key)
    co = coerce(value, ty)
    coi = RubyWrapperBeanAdapter.jit_export(co, value, ty, setter(key))
    rputs @bean, "#{setter}(#{coi})"
    if coi.start_with?("*[") # cheap way to not compute it twice :D
      @bean.send(setter, *co)
    else
      @bean.send(setter, co)
    end
    co
  end

  def has_key?(key)
    raise "NULL PTR" unless key
    getType(key.to_s)
  end

  def read_only?(key)
    setter(key) == nil
  end

  def getPropertyModel(key)
    raise ArgumentError.new unless key
    self[key + PROPERTY_SUFFIX]
  end

  def getType(key)
    raise ArgumentError.new unless key
    if @bean.respond_to? "#{key}GetType" # ruby type support ;-D
      @bean.send("#{key}GetType")
    else
      getter = getter(key)
      getter && getter.return_type
    end
  end

  alias :getGenericType :getType

  def coerce(value, type)
    RubyWrapperBeanAdapter.coerce(value, type)
  end

  def self.jit_export(co, value, ty, setter, ignore=nil)
    coi = co.inspect
    if co.is_a? Java::JavaLang::Enum
      coi = "Java::#{co.java_class.name.gsub(/[\$\.]/, "::")}::#{co.to_s}"
    elsif co.is_a? EventHandlerWrapper
      coi = "EventHandlerWrapper.new(__local_fxml_controller, #{co.funcName.inspect})"
    elsif co.is_a? ScriptEventHandler
      coi = "ScriptEventHandler.new(#{co.script.inspect}, __local_sem_lang_inst_#{rget_sem(co.scriptEngine)})"
    elsif tmp = rget(value)
      coi = tmp
    elsif co.is_a? Java::javafx.scene.paint.Paint
      coi = "RubyWrapperBeanAdapter.coerce(#{value.inspect}, #{ty.ruby_class}.java_class)"
    elsif setter.respond_to? :varargs? and setter.varargs?
      coi = "*#{coi}"
    elsif coi.start_with? "#<"
      #      puts "ignoring #{setting}(#{coi})
      #        How about #{setting}(RubyWrapperBeanAdapter.coerce(#{value.inspect}, #{ty})) ?#

      #      "
      coi = "RubyWrapperBeanAdapter.coerce(#{value.inspect}, #{ty.ruby_class}.java_class)"
    end
    return coi
  end

  def self.coerce( value,  type)
    dputs "coercing..."
    if (type == nil)
      dputs "WHAT!"
      raise "ArgumentError.new();"
    end
    if (value.class == Java::JavaObject)
      dputs "de-objectifying it!!!!"
      dp value.class
      dp value.java_class
      dp value.to_java
      value = value.to_java
    end

    coercedValue = nil;
    if (value == nil)
      # Null values can only be coerced to nil
      coercedValue = nil;
    elsif type == java.lang.Object.java_class || (value.is_a?(EventHandlerWrapper) && type == Java.javafx.event.EventHandler.java_class) || (value.respond_to?(:java_class) && !value.is_a?(EventHandlerWrapper) && type.assignable_from?(value.java_class))
      # Value doesn't require coercion
      coercedValue = value;
    elsif !value.respond_to?(:java_class) && !type.enum?
      # its a ruby value
      dir = ->(x){x}
      to_x = ->(x){->(o){o.send(x)}}
      to_dbl = ->(x){java.lang.Double.valueOf(x.to_s)}
      to_bool = ->(x){java.lang.Boolean.valueOf(x.to_s)}
      value_of = ->(x){type.ruby_class.valueOf(x.to_s)}
      # TODO: Java::double[].java_class.component_type
      mapper = {
        [String, java.lang.String.java_class] => dir,
        [Fixnum, java.lang.Integer.java_class] => dir,
        [Float, java.lang.Double.java_class] => dir,
        [Float, Java::double.java_class] => dir,
        [FalseClass, Java::boolean.java_class] => dir,
        [TrueClass, Java::boolean.java_class] => dir,
        [String, Java::double.java_class] => to_dbl,
        [String, java.lang.Double.java_class] => to_dbl,
        [String, Java::int.java_class] => to_x.call(:to_i),
        [String,java.lang.Integer.java_class] => to_x.call(:to_i),
        [String, Java::boolean.java_class] => to_bool,
        [String, Java::javafx.scene.paint.Paint.java_class] => value_of,
        [String, Java::javafx.scene.paint.Color.java_class] => value_of,
        [String, Java::java.lang.Object.java_class] => dir,
        [String, Java::double[].java_class] => ->(x){x.split(/[, ]+/).map(&:to_f)}
      }
      if mapper[[value.class, type]]
        coercedValue = mapper[[value.class, type]].call(value)
      else
        dputs "!! Non-normal RUBY coerce (#{value}, #{type}) (#{value.inspect}, [#{value.class}, #{type.inspect}])"
        raise "Unknown Coercion map: (#{value}, #{type}) (#{value.inspect}, [#{value.class}, #{type.inspect}]; Please file a bug on this."
      end
      # Ruby String :D
    elsif value.class ==  String && type.enum?
      if value[0] == value[0].downcase
        puts "WHOA Value is not #{value}"
        #TODO: does this need proper snake casing when upcasting?
        value = value.upcase
      end
      coercedValue = type.ruby_class.valueOf(value)
    elsif value.respond_to?(:java_class) && value.java_class == Java::java.net.URL.java_class && type == Java::java.lang.String.java_class
      # TODO: HACK!
      dputs "COnverting url to string"
      coercedValue = value.to_s
    else
      dputs "!! Non-normal coerce (#{value}, #{type}) (#{value.inspect}, #{type.inspect})"
      if (type == java.lang.Boolean.java_class || type == Boolean.TYPE)
        coercedValue = Boolean.valueOf(value.toString());
      elsif (type == Character.java_class            || type == Character.TYPE)
        coercedValue = value.toString().charAt(0);
      elsif (type == Byte.java_class            || type == Byte.TYPE)
        if (value.is_a? Number)
          coercedValue = (value).byteValue();
        else
          coercedValue = Byte.valueOf(value.toString());
        end
      elsif (type == Short.java_class            || type == Short.TYPE)
        if (value.is_a? Number)
          coercedValue = (value).shortValue();
        else
          coercedValue = Short.valueOf(value.toString());
        end
      elsif (type == Integer.java_class            || type == Integer.TYPE)
        if (value.is_a? Number)
          coercedValue = (value).intValue();
        else
          coercedValue = Integer.valueOf(value.toString());
        end
      elsif (type == Long.java_class            || type == Long.TYPE)
        if (value.is_a? Number)
          coercedValue = (value).longValue();
        else
          coercedValue = Long.valueOf(value.toString());
        end
      elsif (type == BigInteger.java_class)
        if (value.is_a? Number)
          coercedValue = BigInteger.valueOf((value).longValue());
        else
          coercedValue = BigInteger.new(value.toString());
        end
      elsif (type == Float.java_class            || type == Float.TYPE)
        if (value.is_a? Number)
          coercedValue = (value).floatValue();
        else
          coercedValue = Float.valueOf(value.toString());
        end
      elsif (type == Double.java_class            || type == Double.TYPE)
        if (value.is_a? Number)
          coercedValue = (value).doubleValue();
        else
          coercedValue = Double.valueOf(value.toString());
        end
      elsif (type == Number.java_class)
        number = value.toString();
        if (number.contains("."))
          coercedValue = Double.valueOf(number);
        else
          coercedValue = Long.valueOf(number);
        end
      elsif (type == BigDecimal.java_class)
        if (value.is_a? Number)
          coercedValue = BigDecimal.valueOf((value).doubleValue());
        else
          coercedValue = BigDecimal.new(value.toString());
        end
      elsif (type == Class.java_class)
        begin
          ReflectUtil.checkPackageAccess(value.toString());
          coercedValue = Class.forName(
            value.to_s,
            false,
            JRuby.runtime.get_class_loader);
        rescue ClassNotFoundException => exception
          raise Exception.new(exception);
        end
      else
        dputs "elsee"
        valueType = value.java_class();
        valueOfMethod = nil;

        while (valueOfMethod == nil                && valueType != nil)
          begin
            dputs "checking access"
            ReflectUtil.checkPackageAccess(type);
            valueOfMethod = type.declared_method(VALUE_OF_METHOD_NAME, valueType);
          rescue NoSuchMethodException => exception
            # No-op
          end

          if (valueOfMethod == nil)
            valueType = valueType.superclass();
          end
        end

        if (valueOfMethod == nil)
          raise IllegalArgumentException.new("Unable to coerce " + value + " to " + type + ".");
        end

        if type.isEnum()                && value.is_a?(String) && value[0] == value[0].downcase
          value = RubyWrapperBeansAdapter.toUpcase value;
        end

        begin
          coercedValue = MethodUtil.invoke(valueOfMethod, nil, [ value ]);
        rescue IllegalAccessException => exception
          dputs "EAI1"
          dp exception
          raise "RuntimeException.new(exception);"
        rescue InvocationTargetException => exception
          dputs "ETI1"
          dp exception
          raise "RuntimeException.new(exception);"
        rescue SecurityException => exception
          dputs "SE1"
          dp exception
          raise "RuntimeException.new(exception);"
        end
      end
    end
    dputs "Coerced #{value.class} into a #{coercedValue.class} for #{type}"
    dp value, coercedValue
    return coercedValue;
  end

  #    /**
  #     * Invokes the static getter method for the given property.
  #     *
  #     * @param target
  #     * The object to which the property is attached.
  #     *
  #     * @param sourceType
  #     * The class that defines the property.
  #     *
  #     * @param key
  #     * The property name.
  #     *
  #     * @return
  #     * The value returned by the method, or <tt>nil</tt> if no such method
  #     * exists.
  #     */
  #    @SuppressWarnings("unchecked")
  def self.get3(target,  sourceType,  key)
    value = nil;

    targetType = target.java_class();
    getterMethod = getStaticGetterMethod(sourceType, key, targetType);

    if (getterMethod != nil)
      begin
        value =  MethodUtil.invoke(getterMethod, nil, [target ] );
      rescue InvocationTargetException => exception
        raise RuntimeException.new(exception);
      rescue IllegalAccessException => exception
        raise RuntimeException.new(exception);
      end
    end

    return value;
  end

  #    /**
  #     * Invokes a static setter method for the given property. If the value is
  #     * <tt>nil</tt> or there is no explicit setter for a given type, the
  #     * {@link #coerce(Object, Class)end method is used to attempt to convert the
  #     * value to the actual property type (defined by the return value of the
  #     * getter method).
  #     *
  #     * @param target
  #     * The object to which the property is or will be attached.
  #     *
  #     * @param sourceType
  #     * The class that defines the property.
  #     *
  #     * @param key
  #     * The property name.
  #     *
  #     * @param value
  #     * The property.new value.
  #     *
  #     * @throws PropertyNotFoundException
  #     * If the given static property does not exist or is read-only.
  #     */
  def self.put3(target,  sourceType, key, value)
    targetType = nil
    if target.respond_to? :java_class
      targetType = target.java_class();
    elsif target.is_a? String
      targetType = java.lang.String.java_class
    else
      dp target, sourceType, key, value
      raise "Shoots!"
    end

    setterMethod = nil;
    if (value != nil)
      valueClass = nil

      if value.respond_to? :java_class
        valueClass = value.java_class();
      elsif value.is_a? String
        valueClass = java.lang.String.java_class
      else
        dp target, sourceType, key, value
        raise "Shoots TWICE!"
      end
      setterMethod = getStaticSetterMethod(sourceType, key, valueClass, targetType);
    end

    if (setterMethod == nil)
      # Get the property type and attempt to coerce the value to it
      propertyType = getType(sourceType, key, targetType);

      if (propertyType != nil)
        setterMethod = getStaticSetterMethod(sourceType, key, propertyType, targetType);
        value = coerce(value, propertyType);
      end
    end

    if (setterMethod == nil)
      raise PropertyNotFoundException.new("Static property \"" + key + "\" does not exist"                + " or is read-only.");
    end

    # Invoke the setter
    begin
      rputs target, "#{sourceType.ruby_class.inspect}.set#{key[0].upcase}#{key[1..-1]}(self, #{jit_export(value, value, targetType, key, "#{sourceType.ruby_class.inspect}.#{key}=")})"
      getStaticSetterMethod(sourceType, key, valueClass, targetType, true).call(target.java_object, value);
    rescue InvocationTargetException => exception
      raise "RuntimeException.new(exception);"
    rescue IllegalAccessException => exception
      raise " RuntimeException.new(exception);"
    end
  end

  #    /**
  #     * Tests the existence of a static property.
  #     *
  #     * @param sourceType
  #     * The class that defines the property.
  #     *
  #     * @param key
  #     * The property name.
  #     *
  #     * @param targetType
  #     * The type of the object to which the property applies.
  #     *
  #     * @return
  #     * <tt>true</tt> if the property exists; <tt>false</tt>, otherwise.
  #     */
  def self.isDefined( sourceType,  key,  targetType)
    return (getStaticGetterMethod(sourceType, key, targetType) != nil);
  end

  #    /**
  #     * Returns the type of a static property.
  #     *
  #     * @param sourceType
  #     * The class that defines the property.
  #     *
  #     * @param key
  #     * The property name.
  #     *
  #     * @param targetType
  #     * The type of the object to which the property applies.
  #     */
  def self.getType(sourceType,  key, targetType)
    getterMethod = getStaticGetterMethod(sourceType, key, targetType);
    return (getterMethod == nil) ? nil : getterMethod.return_type();
  end

  #    /**
  #     * Returns the generic type of a static property.
  #     *
  #     * @param sourceType
  #     * The class that defines the property.
  #     *
  #     * @param key
  #     * The property name.
  #     *
  #     * @param targetType
  #     * The type of the object to which the property applies.
  #     */
  def self.getGenericType( sourceType,  key,  targetType)
    Method getterMethod = getStaticGetterMethod(sourceType, key, targetType);
    return (getterMethod == nil) ? nil : getterMethod.getGenericReturnType();
  end

  #    /**
  #     * Determines the type of a list item.
  #     *
  #     * @param listType
  #     */
  def self.getListItemType(listType)
    itemType = getGenericListItemType(listType);

    if (itemType.is_a? ParameterizedType)
      itemType = (itemType).getRawType();
    end
    dputs "Listem item type is for "
    dp listType, itemType
    return itemType;
  end

  #    /**
  #     * Determines the type of a map value.
  #     *
  #     * @param listType
  #     */
  def self.getMapValueType( mapType)
    valueType = getGenericMapValueType(mapType);

    if (valueType.is_a? ParameterizedType)
      valueType = (valueType).getRawType();
    end

    return valueType;
  end

  #    /**
  #     * Determines the type of a list item.
  #     *
  #     * @param listType
  #     */
  def self.getGenericListItemType(listType)
    itemType = nil;

    parentType = listType;
    dputs "searching for generic #{listType}"
    while (parentType != nil)
      dputs "Still not nill"
      dp parentType
      if (parentType.is_a? ParameterizedType)
        dputs "Parametratized type!"
        parameterizedType = parentType;
        rawType = parameterizedType.getRawType();
        dp rawType, parameterizedType
        if (List.java_class.assignable_from?(rawType))
          itemType = parameterizedType.getActualTypeArguments()[0];
          dputs "OOOOOHHH item type is #{itemType}"
          dp itemType
        end

        break;
      end

      classType = parentType;
      dputs "checinhg generic interfaces"
      genericInterfaces = classType.generic_interfaces();

      genericInterfaces.each do |genericInterface|
        dputs "serarcing ingeraface"
        dp genericInterface
        if (genericInterface.is_a? ParameterizedType)
          parameterizedType = genericInterface;
          interfaceType = parameterizedType.getRawType();
          dputs "checking"
          dp parameterizedType, interfaceType
          if (List.java_class.assignable_from?(interfaceType.java_class)) || (List.java_class.assignable_from?(interfaceType.java_object))
            itemType = parameterizedType.getActualTypeArguments()[0];
            dputs "found it at "
            dp parameterizedType, interfaceType, itemType
            dp itemType.bounds
            break;
          end
        end
      end

      if (itemType != nil)
        break;
      end

      parentType = classType.generic_superclass();
    end

    if (itemType != nil && itemType.is_a?(java.lang.reflect.TypeVariable))
      dputs 'aww shucks'
      dp itemType
      itemType = Java::java.lang.Object.java_class;
    end

    return itemType;
  end

  #    /**
  #     * Determines the type of a map value.
  #     *
  #     * @param mapType
  #     */
  def self.getGenericMapValueType( mapType)
    valueType = nil;

    parentType = mapType;
    while (parentType != nil)
      if (parentType.is_a? ParameterizedType)
        parameterizedType = parentType;
        rawType = parameterizedType.getRawType();

        if (java.util.Map.java_class.assignable_from?(rawType))
          valueType = parameterizedType.getActualTypeArguments()[1];
        end

        break;
      end

      classType = parentType;
      genericInterfaces = classType.getGenericInterfaces();

      genericInterfaces.each do |genericInterface|

        if (genericInterface.is_a? ParameterizedType)
          parameterizedType = genericInterface;
          interfaceType = parameterizedType.getRawType();

          if (java.util.Map.java_class.assignable_from?(interfaceType))
            valueType = parameterizedType.getActualTypeArguments()[1];
            break;
          end
        end
      end

      if (valueType != nil)
        break;
      end

      parentType = classType.getGenericSuperclass();
    end

    if valueType != nil && valueType.is_a?(TypeVariable)
      valueType = Java::java.lang.Object.java_class;
    end

    return valueType;
  end

  #    /**
  #     * Returns the value of a named constant.
  #     *
  #     * @param type
  #     * The type that defines the constant.
  #     *
  #     * @param name
  #     * The name of the constant.
  #     */
  def self.getConstantValue( type,  name)
    if (type == nil)
      raise IllegalArgumentException.new();
    end

    if (name == nil)
      raise IllegalArgumentException.new();
    end

    field = nil
    begin
      field = FieldUtil.getField(type, name);
    rescue NoSuchFieldException => exception
      raise IllegalArgumentException.new(exception);
    end

    int fieldModifiers = field.modifiers();
    if ((fieldModifiers & Modifier.STATIC) == 0            || (fieldModifiers & Modifier.FINAL) == 0)
      raise IllegalArgumentException.new("Field is not a constant.");
    end

    value = nil
    begin
      value = field.get(nil);
    rescue IllegalAccessException => exception
      raise IllegalArgumentException.new(exception);
    end

    return value;
  end

  def self.getStaticGetterMethod( sourceType,  key,         targetType)
    if (sourceType == nil)
      raise ArgumentError.new();
    end

    if (key == nil)
      raise ArgumentError.new();
    end

    method = nil;

    if (targetType != nil)
      key = key[0].upcase + key[1..-1];

      getMethodName = GET_PREFIX + key;
      isMethodName = IS_PREFIX + key;

      begin
        method = MethodUtil.getMethod(sourceType, getMethodName, [ targetType ]);
      rescue NoSuchMethodException => exception
        # No-op
      end

      if (method == nil)
        begin
          method = MethodUtil.getMethod(sourceType, isMethodName, [targetType ]);
        rescue NoSuchMethodException => exception
          # No-op
        end
      end

      # Check for interfaces
      if (method == nil)
        interfaces = targetType.interfaces();
        interfaces.length.times do |i|
          begin
            method = MethodUtil.getMethod(sourceType, getMethodName, [ interfaces[i] ]);
          rescue NoSuchMethodException => exception
            # No-op
          end

          if (method == nil)
            begin
              method = MethodUtil.getMethod(sourceType, isMethodName,  [interfaces[i]] );
            rescue NoSuchMethodException => exception
              # No-op
            end
          end

          if (method != nil)
            break;
          end
        end
      end

      if (method == nil)
        method = getStaticGetterMethod(sourceType, key, targetType.superclass());
      end
    end

    return method;
  end

  def self.getStaticSetterMethod( sourceType,  key,
      valueType,  targetType, rubify=false)
    if (sourceType == nil)
      raise "NULL PTR"
    end

    if (key == nil)
      raise "NULL PTR"
    end

    if (valueType == nil)
      dputs caller
      dp sourceType, key, valueType, targetType, rubify
      raise "NULL PTR"
    end

    method = nil;

    if (targetType != nil)
      key = key[0].upcase + key[1..-1];

      setMethodName = SET_PREFIX + key;
      begin
        unless rubify
          method = MethodUtil.getMethod(sourceType, setMethodName,[ targetType, valueType ]);
        else
          method = sourceType.ruby_class.method(setMethodName)
        end
      rescue NoSuchMethodException => exception
        # No-op
      end

      # Check for interfaces
      if (method == nil)
        interfaces = targetType.interfaces();
        interfaces.length.times do |i|
          begin
            method = MethodUtil.getMethod(sourceType, setMethodName, [ interfaces[i], valueType ]);
          rescue NoSuchMethodException => exception
            # No-op
          end

          if (method != nil)
            break;
          end
        end
      end

      if (method == nil)
        method = getStaticSetterMethod(sourceType, key, valueType, targetType.superclass());
      end
    end

    return method;
  end

  def  self.toAllCaps(value)
    if (value == nil)

      raise "NULL PTR"
    end

    allCapsBuilder = Java.java.lang.StringBuilder.new();

    value.length.times do |i|
      c = value[(i)];

      if (c.upcase == c)
        allCapsBuilder.append('_');
      end

      allCapsBuilder.append(c.upcase);
    end

    return allCapsBuilder.toString();
  end

  def self.for(names)
    if names.is_a? java.lang.Object or (names.is_a? Java::JavaObject and (names = names.to_java))
      RubyWrapperBeanAdapter.new(names)
    else
      RubyObjectWrapperBeanAdapter.new(names)
    end
  end
end
