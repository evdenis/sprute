#!/usr/bin/env python3

import gcc

def on_pass_execution(p, fn):
   if p.name == '*free_lang_data':
      super_ops = set()
      inode_ops = set()
      dentry_ops = set()
      file_ops = set()

      for var in gcc.get_variables():
         if isinstance(var.decl.type, gcc.RecordType):
            ops = None
            if var.decl.type.name.name == 'super_operations':
               ops = super_ops
            elif var.decl.type.name.name == 'inode_operations':
               ops = inode_ops
            elif var.decl.type.name.name == 'file_operations':
               ops = file_ops
            elif var.decl.type.name.name == 'dentry_operations':
               ops = dentry_ops

            if ops != None and var.decl.initial:
               ops.update([b.operand.name for a,b in var.decl.initial.elements])

      if super_ops or inode_ops or dentry_ops or file_ops:
         with open('%s-vfs_ops.sprute' % (gcc.get_dump_base_name()), 'w') as f:
            for i in [['super', super_ops], ['inode', inode_ops], ['dentry', dentry_ops], ['file', file_ops]]:
               if i[1]:
                 f.write( '<' + '#'*20 + ' ' + i[0] + ' ' + '#'*20 + '\n' )
                 f.write('\n'.join(i[1]) + '\n' )
                 f.write( '#'*50 + '>\n' )


gcc.register_callback(gcc.PLUGIN_PASS_EXECUTION, on_pass_execution)

