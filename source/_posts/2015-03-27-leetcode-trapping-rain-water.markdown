---
layout: post
title: "[Leetcode] Trapping Rain Water - 递减栈"
date: 2015-03-27 01:12:24 +0000
comments: true
categories: 

---
### 题目：Trapping Rain Water [点击查看](https://leetcode.com/problems/trapping-rain-water/)
**Given n non-negative integers representing an elevation map where the width of each bar is 1, compute how much water it is able to trap after raining.
For example, 
Given `[0,1,0,2,1,0,1,3,2,1,2,1]`, return `6`.**

![](http://www.leetcode.com/wp-content/uploads/2012/08/rainwatertrap.png)

The above elevation map is represented by array [0,1,0,2,1,0,1,3,2,1,2,1]. In this case, 6 units of rain water (blue section) are being trapped. Thanks Marcos for contributing this image!

- - -

### 解题思路：
时刻维护一个递减的栈。

1. 当前元素比栈顶元素小时，直接进栈；
1. 当前元素大于等于栈顶元素时，弹出栈顶元素，由弹出后新的栈顶元素与当前元素构成一个凹槽，但凹槽并不一定是见底的。比如4、2、3,其中的4和3形成一个凹槽,但因为中间有个2，所以只能容纳1个单位的水。这也就是min(A[k],A[i])-t的原因，t就是这个2，A[k]=4,A[i]=3。

1. 将每次出栈产生的结果加到一起就行了。

``` c++
class Solution {
public:
    int trap(int A[], int n) {
        int top=0;
        if(n<3) return 0;
        s[top++]=0;
        int res=0,t=0,pre=0;
        for(int i=1;i<n;i++)
        {
            while(top>0&&A[i]>=A[s[top-1]])
            {
                t=A[s[--top]];//栈顶元素，能进到这层循环里，说明A[i]比栈顶元素要大
                if(top>0)//弹出刚刚的栈顶元素后,那这次栈顶的元素一定比刚刚弹出的那个大
                {
                    pre=s[top-1];//新的栈顶元素
                    res+=(i-pre-1)*(min(A[k],A[i])-t);//这样新栈顶元素与A[i]这间就形成了一个凹槽
                }
            }
            s[top++]=i;
        }
        
        return res;
    }
private:
    int s[100000];
};
```