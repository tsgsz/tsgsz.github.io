---
title: "浅谈blade中C++Build的设计与实现"
date: 2013-11-01 12:20 +0800
categories: 抛砖引玉
tags: C++
---

[blade] [blade]的背景我也就不详细介绍了，总体来说，
它是腾讯开源的一个构建工具，基于scons而非make，采用python编写，
目前的版本定位于linux下的C++程序。
它的设计思路来源于google的官方博客上的一篇文章，
[Build in the Cloud: How the Build System works] [Build in the Cloud]，
好吧，刚刚发现上面的网址挂了~~，大家将就一下，看[这里] [ch bic]吧,
有兴趣的同学可以去看一下。事实上这是一个系列，
里面讲述了google对大规模协作开发的理解，推荐大家看看。

blade是一个基于scons的构建系统，它做的主要工作是分析代码之间的依赖，
然后生成相应的scons的配置文件SConstruct，由于这一系列生成的中间文件的路径，
都是有blade根据规则自动创建，可以保证每个文件只会被编译一次，
而且中间结果可以被复用，这样就大大提高了大规模构建时的效率。
这篇文章仅仅对blade中的build过程进行分析，不会对run以及test进行描述，
事实上blade对test的支持相当的好，也许有时间研究了我会再写一篇文章来描述，
这是后话，暂且不提。

为了读懂blade，势必要了解什么是scons，scons是一个用python写的构建工具，
这里是它的[官网] [scons]，这篇文章的重点不在scons上面，
所以不会对它的好处和特点进行详细的说明，大家可以参考[这里] [scons good]。
scons是通过读取项目根目录下的SConstruct文件来开始执行构建的，事实上，
SConstruct就是一个python脚本，scons为构建提供了一系列函数，
开发者在写SConstruct时，其实就是在写一个python的脚本。
这里介绍一下scons的简单用法：

*  scons ： 执行SConstruct中的脚本
*  scons -c : 相当于`make clean`，会根据默认规则和SConstruct定义的规则做Clean
*  scons -Q : 只显示编译信息，去除多余的打印信息

scons为它的配置脚本提供了一系列的函数用来构建，这里列举一些常用的：

*  Program : 生成可执行文件，如`Program('foo','foo.cc')`
   将会生成一个名为foo的可执行文件
*  Object : 故名思议，就是用来生成目标文件的函数，如`Object('foo.cc')`，
   在linux下将会生成foo.o
*  Library : 生成静态库和动态库文件，
   其中`SharedLibrary`将会仅仅生生成.so，而`StaticLibrary`将会生成.a
*  SourceSignatures : 判断源文件是否更改，可以通过时间戳或者MD5或者二者来判断
*  TargetSignatures : 判断目标文件是否更改，可以根据编译结果或者是内容来判断
*  Ignore : 用于忽略某个依赖关系，如`Ignore(foo, 'foo.h')`，
   则当foo.h改变时，不会重新编译foo
*  Depends : 用于显示的指定某个依赖关系，如`Depends(foo, joke)`，
   会将joke作为foo的依赖，joke的变更将会导致foo的重新编译
*  Command : 用于执行命令行命令，这个命令比较复杂，这里不详细展开，
   给出官方的[UserGuide] [scons UserGuide-Command]
*  Enviroment : 用于设定环境变量
*  Builder : 用于构建自己的Builder，如
   `foobld = Builder(action = 'foobuild <$SOURCE> <$TARGET>')`，
   这个用法也相对复杂，这里不详细展开，
   可以参考官方的[UserGuide] [scons UserGuide-Builder]
 
以上用法的详细信息都可以在scons的[官方文档] [scons UserGuide]上找到。

介绍完了scons，我们可以正式开始研究blade了。

首先我们来看一下blade的BUILD文件，在BUILD文件中，常用的函数有`cc_library`，
`cc_test`，`cc_binary`，`proto_library`等等，这些函数，做了两件事情，
首先创建一个target，然后将这个target注册给blade。

这里就不得不解释一下什么是target，在blade中，定义了一个抽象的父类叫Target，
它用于描述一个抽象的scons的target，子类如`CcLibrary`，`CcBinary`都会继承于它，
它定义了`get_rules`和`scons_rules`两个公共的抽象方法，
用于获取自身相关的scons rule。target中定义了一系列属性，用于描述该target，
我们主要需要关心的有下面这些：

* name：target的name，就是在BUILD文件中定义的name属性，用来唯一标识一个target
* path：这个属性通过blade来产生，用来标志target的路径
* srcs：这个属性通过BUILD文件中的srcs来定义，存储了target相应的源码文件，
        也有可能是一个目录
* deps：这个属性通过BUILD文件中得deps来定义，存储了target的依赖
* expand\_deps：这个属性通过blade生成，用来表示target中deps的deps
* data：这个属性用来存储各种额外的信息，比如warning，incs等等

上面曾经说到，BUILD文件中你调用的函数，将会把target注册给blade，
于是blade就可以调用该target的`scons_rules`来生成SConstruct中的相应部分。

下面我以一个来举一个例子，来描述blade的build的流程。
首先我们创建一个创建了Fool和Me的代码如下：

{% include_code Fool lang:c++ thinking-in-design-of-blade-cpp-build/fool.h %}

{% include_code Fool lang:c++ thinking-in-design-of-blade-cpp-build/fool.cc %}

{% include_code Me lang:c++ thinking-in-design-of-blade-cpp-build/me.h %}

{% include_code Me lang:c++ thinking-in-design-of-blade-cpp-build/me.cc %}

接着我们建立BUILD文件如下：

{% include_code lang:python thinking-in-design-of-blade-cpp-build/BUILD %}

通过`blade build`命令，
blade将会在blade-bin/test目录下build出一个libfool.a和libme.a。

当在命令行输入了blade build命令，blade做了什么呢？
我们可以从blade\_main.py开始看起：

* 首先自然是要需要解析出build这个动作，将它和相应的函数映射起来，
  可以看到blade\_main中调用了`CmdArguments()`这个方法，
  这个方法由command\_args模块提供，这个方法将会从命令行中parse出command和target、
  options，返回的是blade中真正的处理函数名。
* 接着，blade将找到BLADE\_ROOT所在的目录，将当前目录切换到BLADE\_ROOT所在的目录，
  然后通过configparse这个模块，会解析出blade的config。
  blade不支持多进程编译，也就是说，
  一台机器上只允许有一个blade在同一个BLADE\_ROOT下工作，
  blade采用了文件锁确保了这个机制。
* 之后，blade\_main初始化了一个blade的实例，调用它的blade.generate()的方法，
  在这一步骤中，blade的源代码中给这一句的注释是`# Build the targets`，
  我个人觉得这个注释不太对，事实上blade本身不会真的去build一些target，
  它只是去生成一个scons的SConstruct，而真正的build是在\_build方法中，
  在这个方法中，blade会开启一个新的进程，在这个进程中打开scons，
  这时候，scons才会真正的去build源代码。
* 最后，blade\_main会删除生成的SConstruct。

那么接下来，我们就进入blade的generate方法，来看一看它干了什么？
blade的generate方法如下：

``` python blade generate
def generate(self):
    """Generate the build script. """ 
    self.load_targets()
    self.analyze_targets()
    self.generate_build_rules()
```

可以看到，blade首先会加载所有的目标，这里就包括了去重，依赖展开等等，
然后，blade会去分析目标，得到一个层层依赖的顺序，
最后生成相应的build rule，写入SConstruct中。

到现在为止，关键路径已经出来了，我们来逐层深入，
在blade的`load_target()`函数中做了一大堆的判断，我们暂时不需要关心，
最后它调用了load\_build\_files模块的`load_targets()`函数，我们来看看它的实现：

``` python load_build_files load_targets
def load_targets(target_ids, working_dir, blade_root_dir, blade):
    """load_targets.

    Parse and load targets, including those specified in command line
    and their direct and indirect dependencies, by loading related BUILD
    files.  Returns a map which contains all these targets.

    """
    target_database = blade.get_target_database()

    # targets specified in command line
    cited_targets = set()
    # cited_targets and all its dependencies
    related_targets = {}
    # source dirs mentioned in command line
    source_dirs = []
    # to prevent duplicated loading of BUILD files
    processed_source_dirs = set()

    direct_targets = []
    all_command_targets = []
    # Parse command line target_ids.  For those in the form of <path>:<target>,
    # record (<path>,<target>) in cited_targets; for the rest (with <path>
    # but without <target>), record <path> into paths.
    for target_id in target_ids:
        if target_id.find(':') == -1:
            source_dir, target_name = target_id, '*'
        else:
            source_dir, target_name = target_id.rsplit(':', 1)

        source_dir = relative_path(os.path.join(working_dir, source_dir),
                                    blade_root_dir)

        if target_name != '*' and target_name != '':
            cited_targets.add((source_dir, target_name))
        elif source_dir.endswith('...'):
            source_dir = source_dir[:-3]
            if not source_dir:
                source_dir = './'
            source_dirs.append((source_dir, WARN_IF_FAIL))
            for root, dirs, files in os.walk(source_dir):
                # Skip over subdirs starting with '.', e.g., .svn.
                dirs[:] = [d for d in dirs if not d.startswith('.')]
                for d in dirs:
                    source_dirs.append((os.path.join(root, d), IGNORE_IF_FAIL))
        else:
            source_dirs.append((source_dir, ABORT_IF_FAIL))

    direct_targets = list(cited_targets)

    # Load BUILD files in paths, and add all loaded targets into
    # cited_targets.  Together with above step, we can ensure that all
    # targets mentioned in the command line are now in cited_targets.
    for source_dir, action_if_fail in source_dirs:
        _load_build_file(source_dir,
                         action_if_fail,
                         processed_source_dirs,
                         blade)

    for key in target_database:
        cited_targets.add(key)
    all_command_targets = list(cited_targets)

    # Starting from targets specified in command line, breath-first
    # propagate to load BUILD files containing directly and indirectly
    # dependent targets.  All these targets form related_targets,
    # which is a subset of target_databased created by loading  BUILD files.
    while cited_targets:
        source_dir, target_name = cited_targets.pop()
        target_id = (source_dir, target_name)
        if target_id in related_targets:
            continue

        _load_build_file(source_dir,
                         ABORT_IF_FAIL,
                         processed_source_dirs,
                         blade)

        if target_id not in target_database:
            console.error_exit('%s: target //%s:%s does not exists' % (
                _find_depender(target_id, blade), source_dir, target_name))

        related_targets[target_id] = target_database[target_id]
        for key in related_targets[target_id].expanded_deps:
            if key not in related_targets:
                cited_targets.add(key)

    # Iterating to get svn root dirs
    for path, name in related_targets:
        root_dir = path.split('/')[0].strip()
        if root_dir not in blade.svn_root_dirs and '#' not in root_dir:
            blade.svn_root_dirs.append(root_dir)

    return direct_targets, all_command_targets, related_targets
```

这个函数很长，里面的变量名也晦涩难懂，我贴出来也没指望有人有人会把它真正的读完，
但是，不需要完全的去分析每个细节，我们基本上可以看出这个函数做了两件事情：

1. 找到所有的target
2. load相应的BUILD file

事实上仔细看这个函数的实现，
它无非是将target和它deps中所有target所在的路径解析出来，
然后调用`_load_build_file`这个函数，去加载相应的配置文件，
这个递归过程在这里采用了循环的方式，使得代码读起来有点不容易，
不过循环的方式可以减少栈的深度，有助于效率的提高。
现在一切矛头都指向了`_load_build_file`这个函数，我们来看看它的实现：

``` python load_build_files _load_build_file
def _load_build_file(source_dir, action_if_fail, processed_source_dirs, blade):
    """_load_build_file to load the BUILD and place the targets into database.

    Invoked by _load_targets.  Load and execute the BUILD
    file, which is a Python script, in source_dir.  Statements in BUILD
    depends on global variable current_source_dir, and will register build
    target/rules into global variables target_database.  If path/BUILD
    does NOT exsit, take action corresponding to action_if_fail.  The
    parameters processed_source_dirs refers to a set defined in the
    caller and used to avoid duplicated execution of BUILD files.

    """

    # Initialize the build_target at first time, to be used for BUILD file
    # loaded by execfile
    global build_target
    if build_target is None:
        build_target = TargetAttributes(blade.get_options())
        build_rules.register_variable('build_target', build_target)

    source_dir = os.path.normpath(source_dir)
    # TODO(yiwang): the character '#' is a magic value.
    if source_dir in processed_source_dirs or source_dir == '#':
        return
    processed_source_dirs.add(source_dir)

    if not os.path.exists(source_dir):
        _report_not_exist(source_dir, source_dir, blade)

    old_current_source_path = blade.get_current_source_path()
    blade.set_current_source_path(source_dir)
    build_file = os.path.join(source_dir, 'BUILD')
    if os.path.exists(build_file):
        try:
            # The magic here is that a BUILD file is a Python script,
            # which can be loaded and executed by execfile().
            execfile(build_file, build_rules.get_all(), None)
        except SystemExit:
            console.error_exit('%s: fatal error, exit...' % build_file)
        except:
            console.error_exit('Parse error in %s, exit...\n%s' % (
                    build_file, traceback.format_exc()))
    else:
        if action_if_fail == ABORT_IF_FAIL:
            _report_not_exist(source_dir, build_file, blade)

    blade.set_current_source_path(old_current_source_path)
```

又是一大段的代码，对路径的各种操作，但是还好这些都是细节，如果不去实现，
不需要太过关心，事实上这一段内容的核心是一句代码两行注释：

``` python
   # The magic here is that a BUILD file is a Python script,
   # which can be loaded and executed by execfile().
   execfile(build_file, build_rules.get_all(), None)
```

到这里，是不是有种茅塞顿开的感觉？
在这篇文章的早些时候我曾经花过一下篇幅介绍BUILD，现在我们来回头看一下，
以上面我举的那个BUILD文件为例，execfile函数将会执行BUILD文件中的cc_library函数。
我们来看一下cc_library函数的实现，这个函数在cc_targets模块中，我们可以看一下：

``` python cc_targets cc_library
def cc_library(name,
               srcs=[],
               deps=[],
               warning='yes',
               defs=[],
               incs=[],
               export_incs=[],
               optimize=[],
               always_optimize=False,
               pre_build=False,
               prebuilt=False,
               link_all_symbols=False,
               deprecated=False,
               extra_cppflags=[],
               extra_linkflags=[],
               **kwargs):
    """cc_library target. """
    target = CcLibrary(name,
                       srcs,
                       deps,
                       warning,
                       defs,
                       incs,
                       export_incs,
                       optimize,
                       always_optimize,
                       prebuilt or pre_build,
                       link_all_symbols,
                       deprecated,
                       extra_cppflags,
                       extra_linkflags,
                       blade.blade,
                       kwargs)
    if pre_build:
        console.warning("//%s:%s: 'pre_build' has been deprecated, "
                        "please use 'prebuilt'" % (target.path,
                                                   target.name))
    blade.blade.register_target(target)
```

现在巧妙之处就真正出来了，这个函数其实就是创建一个target对象，
并且将它注册进blade，供后面使用，所以其实遍历一次BUILD文件，
所有的target都自动加载了，在读这段代码的时候，有一种感觉，
就是本来加载就如同收麦子一样，非常辛苦，需要blade一个个去收集，
而现在是走过每片田地，麦子自己就跳进来了。当然这个比喻并不是很准确，
但这个设计的确是相当的巧妙，让人觉得享受。

事实上到这里，后面的代码阅读起来已经没有难度了，现在所有的target已经加载，
接下来就是target的分析了，我们回到blade的主干，`analyze_targets`的实现比较简单，
我这里就不贴上来逐步分析了，
它最后追溯到dependency\_analyzer模块的analyze\_deps函数中，
我们来看一下这个函数的实现：

``` python dependency_analyzer  analyze_deps
def analyze_deps(related_targets):
    """analyze the dependency relationship between targets.

    Input: related targets after loading targets from BUILD files.
           {(target_path, target_name) : (target_data), ...}

    Output:the targets that are expanded and the keys sorted
           [all the targets keys] - sorted
           {(target_path, target_name) : (target_data with deps expanded), ...}

    """
    _expand_deps(related_targets)
    keys_list_sorted = _topological_sort(related_targets)

    return keys_list_sorted
```

可以看到，其实这个地方就是根据依赖关系，将所有的target做了一个拓扑排序，
这个拓扑排序的算法其实很有意思，当然不是我这篇文章的重点，
不过有兴趣的同学可以去看一下。

现在内存中的target都是完整而且有序的了，我们可以安心地生成SConstruct了，
在这一步中，之前target的设计优势就体现了，
每个target根据自己的属性生成自己的scons rule，最后汇总起来，加上文件头，
就是一个完整的SConstruct文件了。我们可以看一下我例子中用blade生成的SConstruct：

{% include_code lang:python thinking-in-design-of-blade-cpp-build/SConstruct %}

可以看到，上面有很多复杂的东西，这篇文章都没有提到，
事实上为了保证编译环境的干净，以及目录结构的清晰，blade还做了环境变量的Clone、
路径的变换等许多工作，希望了解细节的同学可以自己去读一下源代码。

最后，来提一下blade设计上的现有不足：

* 首先，大家可以发现blade这个模块全局贯穿各大模块，
  而事实上很多模块是作为工具模块存在的，不需要了解blade的所有信息，
  直接将blade当做参数传递没有做到信息的隐蔽性。
* 其次，现在的rule_generator在生成SConstruct文件头的时候，是固定生成一些Builder，
  这样就导致如果新增添一种target的类型，会需要修改现有代码，
  可以考虑将Builder的生成分散在各个target中，每个新的target只需要去注册就ok了。
* blade中对Clean的考虑比较少，会有很多中间结果删不掉，
  可以通过在target中定义`Clean`操作来实现。

总体来说，blade是一款非常优秀的开源软件，它的理念很多都是超前的，
这种源码分发，统一环境的理念，事实上对一个公司是一个颠覆式的东西，
“万丈高楼起于基石”，一切创新都将变得事半功倍。

[Build in the Cloud]: http://google-engtools.blogspot.com/2011/08/build-in-cloud-how-build-system-works.html 
[ch bic]: http://blog.sina.com.cn/s/blog_632d74e60100snzj.html
[blade]: https://github.com/chen3feng/typhoon-blade
[scons]: http://www.scons.org
[scons good]: http://wiki.woodpecker.org.cn/moin/PyScons
[scons UserGuide-Command]: http://www.scons.org/doc/production/HTML/scons-user/c3895.html
[scons UserGuide-Builder]: http://www.scons.org/doc/production/HTML/scons-user/c3621.html#AEN3632
[scons UserGuide]: http://www.scons.org/doc/production/HTML/scons-user/index.html
