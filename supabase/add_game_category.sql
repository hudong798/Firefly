-- 修改 archives 表 category CHECK 约束，增加"游戏"分类
ALTER TABLE archives DROP CONSTRAINT IF EXISTS archives_category_check;
ALTER TABLE archives ADD CONSTRAINT archives_category_check 
  CHECK (category IN ('影视', '漫画', '社区', '工具', '游戏'));
