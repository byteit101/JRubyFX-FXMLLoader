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


#/**
# * Class representing an observable expression value.
# */
class RRExpressionValue < Java::javafx.beans.value.ObservableValueBase
  #// Monitors a namespace for changes along a key path



  def initialize(namespace, expression, type)
    super()
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
    @argumentMonitors = java.util.ArrayList.new(arguments.size());

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


  class ListChangeImpl
    include ListChangeListener

    def initialize(this)
      @this = this
    end

    def onChanged(change)
      @this.list_changed(change)
    end
  end


  class MapChangeImpl
    include MapChangeListener

    def initialize(this)
      @this = this
    end

    def onChanged(change)
      @this.map_changed(change)
    end
  end



  class ChangeListenerImpl
    include ChangeListener

    def initialize(this)
      @this = this
    end

    def changed(ov, old, new)
      @this.normal_changed(ov, old, new)
    end
  end

  def initialize(this, keyPathIterator)
    @key = keyPathIterator.next();
    @this = this


    @listChangeListener = ListChangeImpl.new(self)


    @mapChangeListener = MapChangeImpl.new(self)


    @propertyChangeListener = ChangeListenerImpl.new(self)

    if (keyPathIterator.hasNext())
      @next = KeyPathMonitor.new(this, keyPathIterator);
    else
      @next = nil;
    end
  end

  def list_changed(change)
    while (change.next())
      index = @key.to_i

      if (index >= change.getFrom() && index < change.getTo())
        @this.fireValueChangedEvent();
        remonitor();
      end
    end
  end

  def map_changed(change)
    if (@key == (change.getKey()))
      @this.fireValueChangedEvent();
      remonitor();
    end
  end

  def normal_changed(observable, oldValue, newValue)
    if (@key == (observable.getName()))

      @this.fireValueChangedEvent();
      remonitor();
    end
  end

  def monitor(namespace)
    if (namespace.is_a? ObservableList)
      old_verbose = $VERBOSE
      begin
        $VERBOSE = nil
        namespace.addListener @listChangeListener
      ensure
        # always re-set to old value, even if block raises an exception
        $VERBOSE = old_verbose
      end
    elsif (namespace.is_a? ObservableMap)
      old_verbose = $VERBOSE
      begin
        $VERBOSE = nil
        namespace.addListener @mapChangeListener
      ensure
        # always re-set to old value, even if block raises an exception
        $VERBOSE = old_verbose
      end
    else
      namespaceAdapter = RubyWrapperBeanAdapter.for(namespace);
      propertyModel = namespaceAdapter.getPropertyModel(@key).to_java
      if (propertyModel != nil)
        old_verbose = $VERBOSE
        begin
          $VERBOSE = nil
          propertyModel.addListener @propertyChangeListener
        ensure
          # always re-set to old value, even if block raises an exception
          $VERBOSE = old_verbose
        end
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
      old_verbose = $VERBOSE
      begin
        $VERBOSE = nil
        @namespace.removeListener @listChangeListener
      ensure
        # always re-set to old value, even if block raises an exception
        $VERBOSE = old_verbose
      end
    elsif (@namespace.is_a? ObservableMap)
      old_verbose = $VERBOSE
      begin
        $VERBOSE = nil
        @namespace.removeListener @mapChangeListener
      ensure
        # always re-set to old value, even if block raises an exception
        $VERBOSE = old_verbose
      end
    elsif (@namespace != nil)
      namespaceAdapter = @namespace;
      propertyModel = namespaceAdapter.getPropertyModel(@key);

      if (propertyModel != nil)
        old_verbose = $VERBOSE
        begin
          $VERBOSE = nil
          propertyModel.removeListener @propertyChangeListener
        ensure
          # always re-set to old value, even if block raises an exception
          $VERBOSE = old_verbose
        end
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

