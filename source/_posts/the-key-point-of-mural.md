---
title: 画中人设计的关键点
date: 2018-07-15 23:55:46
categories: 抛砖引玉
tags: 画中人
---

画中人设计的关键点在于规则驱动, 区别于之前的 rpg 人为设定任务,
新的设计方案需要规则驱动, 因此从玩家的角度来看 Hero 和其他 NPC 并无区别.
根据时钟, 画中人的世界应该隔一段时间就触发一次随机事件, 
玩家和每个 NPC 都会为此事件作出选择从而改变下一次随机事件产生的条件.
随机事件是由先决条件和骰子来决定的.

同时由于玩家可以有目的地自己触发事件(比如交谈, 战斗, 做任务), 
NPC 也应该随着时间间隔做出相应抉择, 不过是以事件的形式, 
此处 NPC 的抉择应该是 AI 算法, 早期版本可以通过简单的决策树来实现.

若 NPC 与 HERO 处于同一张地图, 则 AI 的决策将滞后, 
等 HERO 离开地图之后下一次决策会执行多次, 用来修改 NPC 的数值

游戏的事件结构应该设计如下:

    触发条件 -> 触发主体 -> 抉择 -> 影响

其中触发条件是一系列游戏类的环境变量, 影响也是这样

在画中人的世界中, 应该存在个体本身的变量和游戏中的环境变量, 具体数值还需要细想