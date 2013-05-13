#/*
# * Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
# * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
# *
# * This code is free software; you can redistribute it and/or modify it
# * under the terms of the GNU General Public License version 2 only, as
# * published by the Free Software Foundation.  Oracle designates this
# * particular file as subject to the "Classpath" exception as provided
# * by Oracle in the LICENSE file that accompanied this code.
# *
# * This code is distributed in the hope that it will be useful, but WITHOUT
# * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# * version 2 for more details (a copy is included in the LICENSE file that
# * accompanied this code).
# *
# * You should have received a copy of the GNU General Public License version
# * 2 along with this work; if not, write to the Free Software Foundation,
# * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
# *
# * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
# * or visit www.oracle.com if you need additional information or have any
# * questions.
# */

#package com.sun.javafx.fxml.expression;
#
#import java.util.ArrayList;
#import java.util.Iterator;
#import java.util.List;
#
#import javafx.beans.InvalidationListener;
#import javafx.beans.property.ReadOnlyProperty;
#import javafx.beans.value.ChangeListener;
#import javafx.beans.value.ObservableValue;
#import javafx.beans.value.ObservableValueBase;
#import javafx.collections.ListChangeListener;
#import javafx.collections.MapChangeListener;
#import javafx.collections.ObservableList;
#import javafx.collections.ObservableMap;
#
#import com.sun.javafx.fxml.BeanAdapter;

#/**
# * Class representing an observable expression value.
# */
class RRExpressionValue < Java::javafx.beans.value.ObservableValueBase
  #// Monitors a namespace for changes along a key path
    


  def initialize(namespace, expression, type)
    super()
    dputs "Initializing with #{namespace}, #{expression}, #{type}"
    if (namespace == nil) 
      raise "NullPointerException.new();"
    end

    if (expression == nil)
      raise "NullPointerException.new();"
    end

    if (type == nil) 
      raise "NullPointerException.new();"
    end

    @listenerCount = 0;

    @namespace = namespace;
    @expression = expression;
    @type = type;

    arguments = expression.getArguments();
    @argumentMonitors = ArrayList.new(arguments.size());

    for  argument in arguments
      @argumentMonitors.add(KeyPathMonitor.new(self, argument.iterator()));
    end
  end

    
  def getValue() 
    return RubyWrapperBeanAdapter.coerce(@expression.evaluate(@namespace), @type);
  end

  def addListener( listener) 
    if (@listenerCount == 0) 
      monitorArguments();
    end

    super(listener);
    @listenerCount += 1
  end

  def removeListener( listener) 
    super(listener);
    @listenerCount-=1

    if (@listenerCount == 0) 
      unmonitorArguments();
    end
  end

  def monitorArguments() 
    for  argumentMonitor in @argumentMonitors
      argumentMonitor.monitor(@namespace);
    end
  end

  def unmonitorArguments() 
    for  argumentMonitor in   @argumentMonitors
      argumentMonitor.unmonitor();
    end
  end
end

                    
class KeyPathMonitor 
  @key = nil;
  @next = nil

  @namespace = nil;

        

  def initialize(this, keyPathIterator) 
    @key = keyPathIterator.next();
    @this = this
    
          
    @listChangeListener = ListChangeListener.impl do |name, change|
      while (@change.next()) 
        index = @key.to_i

        if (index >= change.getFrom() && index < change.getTo()) 
          @this.fireValueChangedEvent();
          remonitor();
        end
      end
    end
        

    @mapChangeListener = MapChangeListener.impl do |name, change|
      if (@key == (change.getKey())) 
        @this.fireValueChangedEvent();
        remonitor();
      end
    end
        

    @propertyChangeListener = ChangeListener.impl do |name, observable, oldValue, newValue|
      if (@key == (observable.getName())) 
        @this.fireValueChangedEvent();
        remonitor();
      end
    end

    if (keyPathIterator.hasNext()) 
      @next = KeyPathMonitor.new(this, keyPathIterator);
    else 
      @next = nil;
    end
  end

  def monitor(namespace) 
    if (namespace.is_a? ObservableList) 
      namespace.addListener(@listChangeListener);
    elsif (namespace.is_a? ObservableMap) 
      namespace.addListener(@mapChangeListener);
    else 
      namespaceAdapter = RubyWrapperBeanAdapter.for(namespace);
      propertyModel = namespaceAdapter.getPropertyModel(@key).to_java

      if (propertyModel != nil) 
        propertyModel.addListener(@propertyChangeListener);
      end

      @namespace = namespaceAdapter;
    end

    @namespace = namespace;

    if (@next != nil) 
      value = Expression.get(@namespace, @key)
      if (value != nil) 
        @next.monitor(value);
      end
    end
  end

  def unmonitor() 
    if (@namespace.is_a? ObservableList) 
      @namespace.removeListener(@listChangeListener)
    elsif (@namespace.is_a? ObservableMap) 
      @namespace.removeListener(@mapChangeListener)
    elsif (@namespace != nil) 
      namespaceAdapter = @namespace;
      propertyModel = namespaceAdapter.getPropertyModel(@key);

      if (propertyModel != nil) 
        propertyModel.removeListener(@propertyChangeListener);
      end
    end

    @namespace = nil;

    if (@next != nil) 
      @next.unmonitor();
    end
  end

  def remonitor() 
    if (@next != nil) 
      @next.unmonitor();
      value = Expression.get(@namespace, @key);
      if (value != nil) 
        @next.monitor(value);
      end
    end
  end
end

#class JRExpressionTargetMapping < ChangeListener
#
#    def initialize(paramExpression,  paramObject, paramList)
#    
#      @source = paramExpression;
#      @target = paramObject;
#      @path = paramList;
#    end
#
#    def changed(ov, ol, ne)
#    
#      if (@source.isDefined())
#        Expression.set(@target, @path, @source.getValue());
#      end
#    end
#end
 