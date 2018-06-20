// Copyright 2013, Kingslanding Inc.
// Author: Pine <cdtsgsz@gmail.com>
//
// Description: simple test code

#ifndef TEST_ME_H_
#define TEST_ME_H_

#include "test/fool.h"

namespace kingslanding {
namespace test {
class Me {
    public:
        void IntroduceSelf();
    private:
        Fool m_fool;
};
}  // namespace test
}  // namespace kingslanding
#endif  // TEST_ME_H_
