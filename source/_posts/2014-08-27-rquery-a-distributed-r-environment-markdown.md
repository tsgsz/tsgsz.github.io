---
title: " RQuery-分布式 R"
date: 2014-08-27 12:00:31 +0800
categories:  抛砖引玉
tags: 分布式
---

工作需要，组里设计了一个叫 RQuery 的分布式 R 环境。

我们都知道 R 是一门强大的数据处理语言（或者叫做数据处理工具更合适），
R 有一些很强大的特性，比如 R 中可以很方便的插入 sql，
执行 sql 查询之后得到 data.frame，
然后利用 R 本身强大的库函数去做各种各样的运算。

然而强大的 R 有一个限制，那就是它事实上是单机的程序，
当你有一堆巨大无比的数据集，比如好几百T甚至上P的时候，
单机的 R 就无法用来做数据分析了，
业界事实上有很多分布式的系统来做数据分析比如 Storm，Pig。
然而对于一个传统的数据分析人员来说，
在思考数据本身的同时还要去理解分布式的算法是一件很麻烦的事，
而且这些系统也没有直接支持 R，matlab 这样高级的适合于数据分析人员使用的工具。
在这样的背景下，RQuery 产生了。

RQuery 在设计上尽可能的屏蔽了分布式相关的东西，使得 api 和 R 原生的 api 相近。
举个例子：

{% include_code lang:R rquery-a-distributed-r-environment/read_table.R %}

上面的代码是在 R 中去 read 一个本地的 text 文件，并且进行了一系列操作，

{% include_code lang:R rquery-a-distributed-r-environment/read_dtable.R %}

这里面，Sample 是事先在 meta 中建好一张表，
对应的是存在分布式文件系统上的一堆文件。

可以看到上下的 R 代码写起来差距很小。这样就给传统的数据分析人员极大的便利。
再举一个 kmeans 的例子：

{% include_code lang:R rquery-a-distributed-r-environment/kmeans_r.R %}

{% include_code lang:R rquery-a-distributed-r-environment/kmeans_dr.R %}

可以看到用法基本一致。

RQuery 抽象出了一个数据结构叫做 dtable，并且提供了如下 API：

```
    select(dt, expr)  # 类似于 sql 中的 select
    where(dt, expr)  # 类似于 sql  中的 where
    count(dt)  # dt 中的行数 
    take(dt, 10)  # 取 dt 中的前10行
    collect(dt)  # 将 dt 中的数据拿到本地
    takeSample(dt)  # 从 dt 中采样并拿到本地
```

然后我们目前提供了四个 api，供用户在 dtable 上做分布式的算法操作，
之后会给出更多地算法 api：

```
    dtable(name)  # 创建一个 dtable
    rquery(sql)  # 执行一条 sql 语句
    rquery.collect(sql)  # 执行一条 sql 语句
    rquery.kmeans(dt, k)  #  执行 kmeans 算法
```

当然，目前来说 RQuery 还很不成熟，缺失了诸多的 api，
虽然可以方便的在分布式和本地切换，但是 dtable 还有很多操作不能直接进行，
需要一步转换，后续会支持更多地 R 本地的 api，提供机器学习十大经典算法，
让在分布式上执行 R 运算和在本地一样便捷！
