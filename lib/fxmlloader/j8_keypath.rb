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

java_import %w[java.io.IOException
java.io.PushbackReader
java.io.StringReader
java.util.AbstractList
java.lang.StringBuilder
java.util.ArrayList]
#class KPIterator
#  include java.util.Iterator
#  def intialize(obj)
#    @obj = obj
#    @itm = 0
#  end
#
#  def hasNext
#    @obj.length >= @itm
#  end
#
#  def next
#    @obj[(@itm+=1) - 1]
#  end
#end
#/**
# * Class representing a key path, an immutable list of string keys.
# */
class KeyPath < AbstractList
    @elements = nil
    @iter = 0

    def initialize( elements)
      super()
        if (elements == nil)
            throw NullPointerException.new();
        end
        dputs "built with "
        dp elements
        @elements = elements;
    end

    def get(index)
      dputs "caled get(#{index}"
        return @elements[index]
    end

    def length
      dputs "length was called"
        return @elements.length
    end
    def size
      dputs "size was called"
        return @elements.length
    end

    def hasNext
      dputs "hasHExt was called"
      # TODO: fix
      return @elements.hasNext
    end

    def iterator
      dputs "iterator was calle"
      return @elements.iterator
      return KPIterator.new(@elements)
    end

    def to_s
      dputs "to_s was called"
        stringBuilder = StringBuilder.new();

        @elements.length.times do |i|
            element = @elements[i]

            if (java.lang.Character.isDigit(element[0]))
                stringBuilder.append("[");
                stringBuilder.append(element);
                stringBuilder.append("]");
            else
                if (i > 0)
                    stringBuilder.append(".");
                end

                stringBuilder.append(element);
            end
        end

        return stringBuilder.toString();
    end

#    /**
#     * Parses a string value into a key path.
#     *
#     * @param value
#     * The string value to parse.
#     *
#     * @return
#     * The resulting key path.
#     */
    def self.parse( value)
        keyPath = nil
        begin
            reader = PushbackReader.new(StringReader.new(value));

            begin
                keyPath = parsei(reader);
            ensure
                reader.close();
            end
        rescue IOException => exception
          p exception
            raise "RuntimeException.new(exception);"
        end

        return keyPath;
    end

#    /**
#     * Parses character content from a reader into a key path. If the character
#     * following the key path is not EOF, it is pushed back.
#     *
#     * @param reader
#     * The reader containing the content to parse.
#     *
#     * @return
#     * The resulting key path.
#     */
    def self.parsei(reader)
        elements = java.util.LinkedList.new

        c = reader.read();

        while (c != -1 && (java.lang.Character.java_send(:isJavaIdentifierStart, [Java::int] ,c) || c == '['))
            keyBuilder = StringBuilder.new();

             bracketed = (c == '[');

            if (bracketed)
                c = reader.read();
                 quoted = (c == '"' || c == '\'');

                 quote = nil
                if (quoted)
                    quote = c.chr;
                    c = reader.read();
                else
                    quote = java.lang.Character.UNASSIGNED;
                end

                while (c != -1  && bracketed)
                    if (Character.isISOControl(c))
                        raise IllegalArgumentException.new("Illegal identifier character.");
                    end

                    if (!quoted                       && !java.lang.Character.isDigit(c))
                        raise IllegalArgumentException.new("Illegal character in index value.");
                    end

                    keyBuilder.append(c.chr);
                    c = reader.read();

                    if (quoted)
                        quoted = c != quote;

                        if (!quoted)
                            c = reader.read();
                        end
                    end

                    bracketed = c != ']';
                end

                if (quoted)
                    raise IllegalArgumentException.new("Unterminated quoted identifier.");
                end

                if (bracketed)
                    raise IllegalArgumentException.new("Unterminated bracketed identifier.");
                end

                c = reader.read();
             else
                while(c != -1 && (c != '.' && c != '[' && java.lang.Character.java_send(:isJavaIdentifierPart, [Java::int] ,c)))
                    keyBuilder.append(c.chr);
                    c = reader.read();
                end
            end

            if (c == '.')
                c = reader.read();

                if (c == -1)
                    raise IllegalArgumentException.new("Illegal terminator character.");
                end
            end

            if (keyBuilder.length() == 0)
                raise IllegalArgumentException.new("Missing identifier.");
            end

            elements << (keyBuilder.toString());
        end

        if (elements.length == 0)
            raise IllegalArgumentException.new("Invalid path.");
        end

        # Can't push back EOF; subsequent calls to read() should still return -1
        if (c != -1)
            reader.unread(c);
        end

        return KeyPath.new(elements);
    end
end
