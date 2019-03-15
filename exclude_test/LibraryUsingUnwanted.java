package exclude_test;

import java.lang.reflect.*;

public class LibraryUsingUnwanted {
  public static boolean doit() {
    Dependency dependency = new Dependency();
    return dependency.doit();
  }

  public static boolean runtime_doit()
      throws ClassNotFoundException, InstantiationException, NoSuchMethodException,
          IllegalAccessException, InvocationTargetException {
    Class<?> runtimeDepClass = Class.forName("exclude_test.RuntimeDependency");
    Object runtimeDep = runtimeDepClass.newInstance();
    Method doitMethod = runtimeDep.getClass().getMethod("doit");
    boolean result = (boolean) doitMethod.invoke(runtimeDep);
    return result;
  }
}
