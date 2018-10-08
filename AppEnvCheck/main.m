//
//  main.m
//  AppEnvCheck
//
//  Created by liaogang on 2018/9/30.
//  Copyright © 2018年 liaogang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "fishhook.h"
#import "defs.h"
#import <dlfcn.h>
#include <mach-o/dyld_images.h>

#include <stdio.h>

#include <mach/mach_init.h>
#include <mach/mach_port.h>
#include <mach/task_info.h>
#include <mach/thread_act.h>
#include <mach/vm_map.h>
#include <mach/task.h>

#include <sys/types.h>
#include <sys/time.h>
#include <sys/proc.h>
//#include <sys/ptrace.h>
#include <sys/sysctl.h>
//#include <sys/vnode.h>

#include <math.h>
#include <time.h>
#include <signal.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>

@import Darwin.POSIX.pthread.pthread;
@import Darwin.Mach.mach_init;
@import Darwin.Mach.task;
@import MachO.loader;


typedef struct HookNode {
    int64 a;   //+0
    void* beg; //+8
    void* end; //+16
    
    BYTE isMain; //+24
    BYTE index;
    BYTE arg1;
    BYTE arg2;
    
    BYTE arg3;
    BYTE arg4;
    BYTE arg5;
    BYTE arg6;
    
    struct HookNode *next; //+32
} HookNode;


static struct HookNode *rootNode = NULL;

//QWORD qword_103211130;


//检测函数地址是不是位于__Text之中
BOOL checkFishHook(void *funcAddr)
{
    struct HookNode *curr = rootNode;
    if ( curr == NULL )
    {
        return TRUE;
    }
    
    struct HookNode *next = rootNode->next;

    if ( next == NULL )
    {
        return 0;
    }
    

    while (funcAddr >= curr->end ||
           funcAddr <= curr->beg ||
           curr->isMain
           ) {
        curr = next;
        next = next->next;
        
        if (next == NULL) {
            return FALSE;
        }
    }

    return TRUE;
}


//mach_header**,v2,a3
// find Load Commands , where segment name == '__TEXT' from mach_header
// a2, a3   file begin -> file end?
__int64 find_load_commands(__int64 result, __int64 *a2, _QWORD *a3)
{
    _QWORD *v3; // x19
    __int64 *v4; // x20
    __int64 v5; // x21
    unsigned int v6; // w24
    __int64 v7; // x26
    int v8; // w25
    signed __int64 v9; // x23
    __int64 v10; // x8
    
    v3 = a3;
    v4 = a2;
    v5 = result;
    struct mach_header *header = (struct mach_header *)result;
    v6 = *(_DWORD *)(result + 16); // header->ncmds
    if ( v6 )
    {
        v7 = 0LL;
        v8 = 0;
        v9 = result + 0x20 ; // ,     _PAGEZERO
        while ( 1 )
        {
            if ( *(_DWORD *)v9 == 0x19 )     // value == 0x19
            {
                if ( !v7 )
                {
                    //result + 48,  result + 50
                    //command size ,file size
                    if ( *(_QWORD *)(v9 + 0x28) || !*(_QWORD *)(v9 + 0x30 ) )
                        v7 = 0LL;
                    else
                        //result + 0x38 , vm address
                        v7 = v5 - *(_QWORD *)(v9 + 0x18 );
                    // v7 = (header - vm address)
                }
                
                //result + 0x28, segment name
                result = strcmp((const char *)(v9 + 0x08), "__TEXT");
                if ( !(_DWORD)result )
                    break;
            }
            v9 += *(unsigned int *)(v9 + 4);
            if ( ++v8 >= v6 )
                return result;
        }
        
        //result + 0x48 , result + 38
        //file offset + (header - *vm address) + vmaddress?
        //
        v10 = *(_QWORD *)(v9 + 0x28) + v7 + *(_QWORD *)(v9 + 0x18);
        *v4 = v10;
        //v4 = file offset + header ?
        
        //file size
        *v3 = v10 + *(_QWORD *)(v9 + 0x30);
        
    }
    return result;
}




pthread_mutex_t unk_1032AA700;
void _prepare_root()
{
    rootNode = malloc(sizeof(HookNode));
    bzero(rootNode, sizeof(HookNode));
}

struct dyld_uuid_info *get_next(struct dyld_uuid_info *i)
{
    return i + 1;
//    int sz = sizeof(struct dyld_uuid_info);
//    return (struct dyld_uuid_info *) ((char*)i + sz);
}

__int64 prepare_fish_hook_check()
{
    _prepare_root();
    
    void *v0; // x19
    __int64 result; // x0
//    __int64 v3; // x8
    
    struct HookNode *curr;
    __int64 *v4; // x22
    
//    __int64 i; // x24
    struct HookNode *i;

    
    struct HookNode *next;
//    _QWORD *v8; // x0
    _QWORD *j; // x8
    _QWORD *v10; // x19
    __int64 v11; // [xsp+8h] [xbp-78h]
    __int64 v12; // [xsp+10h] [xbp-70h]
    integer_t task_info_out[TASK_DYLD_INFO_COUNT]; // [xsp+18h] [xbp-68h]
    mach_msg_type_number_t task_info_outCnt; // [xsp+2Ch] [xbp-54h]
    Dl_info v15; // [xsp+30h] [xbp-50h]
    
    
    
    //dladdr(prepare_fish_hook_check, &v15);
    //v0 = v15.dli_fbase;
    
    
    task_info_outCnt = TASK_DYLD_INFO_COUNT;
    //0x11u
    result = task_info( mach_task_self_ , TASK_DYLD_INFO , task_info_out, &task_info_outCnt);
    if ( result == KERN_SUCCESS )
    {
        struct task_dyld_info dyld_info = *(struct task_dyld_info*)(void*)(task_info_out);
        struct  dyld_all_image_infos* infos = (struct dyld_all_image_infos *) dyld_info.all_image_info_addr;

        struct dyld_uuid_info* pUuid_info  = infos->uuidArray; //v4

        curr = rootNode;

        
        if ( infos->uuidArrayCount )
        {
            unsigned __int64 index = 1;
            
            for ( i = rootNode ; ;  )
//            for ( i = qword_103211130; ;  )
            {
                const struct mach_header *header =  pUuid_info->imageLoadAddress;

                
                i->isMain = (header == (_QWORD)v0);
//                *(_BYTE *)(i + 24) = (header == (_QWORD)v0);
                
                curr->index = (signed __int64)(index - 1) > 1;
//                *(_BYTE *)(v3 + 25) = (signed __int64)(index - 1) > 1;

                
                find_load_commands(header, &v12, &v11);
                
                
                i->beg = v12;
                i->end = v11;
//                *(_QWORD *)(i + 8) = v12;
//                *(_QWORD *)(i + 16) = v11;
                
                
                next = i->next;
//                v8 = *(_QWORD **)(i + 32);
                if ( next == NULL )
                {
                    next = malloc(sizeof(struct HookNode));
                    bzero(next, sizeof(struct HookNode));
                    i->next = next;
                }
                
                
                if ( index >= infos->uuidArrayCount )
                    break;
                
                pUuid_info = get_next(pUuid_info);
                curr = rootNode;
                ++index;
                i = next;
            }
            
            
            curr = next;
        }
        else
        {
            next = rootNode;
        }
        
        
        for ( j = *(_QWORD **)(curr + 32); j; next = v10 )
        {
            v10 = j;
            //            free(v8);
            j = (_QWORD *)v10[4];
        }
    }
    
    
    return 0;
}






static int (*orig_open)(const char *, int, ...);
int new_open(const char *path, int oflag, ...) {
    va_list ap = {0};
    mode_t mode = 0;
    
    if ((oflag & O_CREAT) != 0) {
        // mode only applies to O_CREAT
        va_start(ap, oflag);
        mode = va_arg(ap, int);
        va_end(ap);
        printf("Calling real open('%s', %d, %d)\n", path, oflag, mode);
        return orig_open(path, oflag, mode);
    } else {
        printf("Calling real open('%s', %d)\n", path, oflag);
        return orig_open(path, oflag, mode);
    }
}



int main(int argc, char * argv[]) {
    
    
    // 初始化一个 rebinding 结构体
    struct rebinding open_rebinding = { "open", (void*)new_open, (void **)&orig_open };
    
    // 将结构体包装成数组，并传入数组的大小，对原符号 open 进行重绑定
    rebind_symbols((struct rebinding[1]){open_rebinding}, 1);
    
    
    
    
    open("/var/mobile/Media/a.txt", 'r');
    
    //初始化链表
    prepare_fish_hook_check();
    
    
    int hooked;
    
    hooked = checkFishHook( (unsigned __int64)&open);
    printf("hooked: %d\n",hooked);
    
    hooked = checkFishHook( (unsigned __int64)&dladdr);
    printf("hooked: %d\n",hooked);
    
    hooked = checkFishHook( (unsigned __int64)&open);
    printf("hooked: %d\n",hooked);
    
    hooked = checkFishHook( (unsigned __int64)&dladdr);
    printf("hooked: %d\n",hooked);
    

    
    
    
    
    while (getchar() == 'q') {
        return 0;
    }
    
    
    while (1) {
        sleep(3);
    }
    
    
    
    return 0;
}
