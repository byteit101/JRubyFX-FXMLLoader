java_import 'com.sun.javafx.fxml.BeanAdapter'
class BeanAdapter
  def inspect
    "Sombody's Bean'"
  end

  def [](x)
    get(x)
  end

  def []=(x, y)
    put(x, y)
  end

  def read_only?(name)
    isReadOnly(name)
  end
end
class RubyWrapperBeanAdapter < BeanAdapter
end

class Java::javafx::fxml::JavaFXBuilder::ObjectBuilder
  def inspect
    "Its a builder..."
  end
  def size
    900000
  end
end