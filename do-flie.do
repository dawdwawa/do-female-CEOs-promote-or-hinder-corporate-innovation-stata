* 切换到数据所在路径(根据自己路径修改)
cd D:\女性高管对企业创新影响研究


* 结果输出路径
global res_path D:\女性高管对企业创新影响研究\输出



*= 导入事件日期数据
import excel D:\女性高管对企业创新影响研究\FS_Combas.xlsx, firstrow clear
save balance_clean.dta, replace
import excel D:\女性高管对企业创新影响研究\FS_comins.xlsx, firstrow clear
save income_clean.dta, replace
import excel D:\女性高管对企业创新影响研究\CG_Director.xlsx, firstrow clear
save ceo_clean.dta, replace
import excel D:\女性高管对企业创新影响研究\STK_LISTEDCOINFOANL.xlsx, firstrow clear
save industrycode.dta, replace

*=构建女性高管变量
*=将“男女”变为 女==1，男==0，以stkcd，accper为根据加总构建单一年度的女性高管变量female——num
*= 去掉多余重复值
use ceo_clean.dta, replace
gen female_ceo = (gender_ceo == "女") if !missing(gender_ceo)
bysort stkcd accper: egen female_num = sum(female_ceo)
deplicates drop stkcd accper,force
save ceo_clean.dta, replace

* 合并数据
use balance_clean.dta,replace
merge 1:1 stkcd accper using ceo_clean.dta
drop if_merge==2
drop _merge
merge 1:1 stkcd accper using income_clean.dta
drop if_merge==2
drop _merge
merge 1:1 stkcd accper using industrycode.dta
drop if_merge==2
drop _merge

*=剔除ST *ST PT退市样本,金融行业样本以及样本周期内唯一观测值
drop if strmatch(shortname,"*ST*")
drop if strmatch(shortname,"*PT*")
drop if strmatch(shortname,"*退*")
drop if strmatch(industry_code,"*J*")
bysort stkcd:drop if _N==1
save data.dta, replace


*=生成控制变量
*= 生成因变量：研发强度（R&D/销售收入）
gen rd_intensity = rd_expenditure / revenue if rd_expenditure != . & revenue != .
*=生成控制变量
*=企业规模（总资产对数）
gen log_assets = ln(total_assets)
*=资本结构（资产负债率）
gen leverage = total_debt / total_assets 
*=资产有形性
gen tangibility = fixed_assets / total_assets
*=流动比率
gen current_ratio = current_assets / current_liabilities 
*=缩尾处理（1%和99%）
winsor2 rd_intensity log_assets leverage tangibility current_ratio, cuts(1 99) replace
*=剔除缺失值
drop if missing(rd_intensity, female_ceo, log_assets, leverage, tangibility, current_ratio)
*=生成年份和行业虚拟变量
tab year, gen(year_dummy)
tab industry_code, gen(ind_dummy)


*=生成描述性统计表 
estpost summarize rd_intensity female_ceo log_assets leverage tangibility current_ratio
esttab using "Descriptive_Stats.rtf", cells("mean(fmt(3)) sd(fmt(3)) min(fmt(2)) max(fmt(2))") replace

*=生成相关系数矩阵（带*号标注显著性）
estpost correlate rd_intensity female_ceo log_assets leverage tangibility current_ratio, matrix listwise
esttab . using "Correlation_Matrix.rtf", unstack not noobs compress star(* 0.05) replace
*=绘制散点图和拟合线
twoway (scatter rd_intensity log_assets) (lfit rd_intensity log_assets) (qfit rd_intensity log_assets), ///
       title("Innovation Intensity vs Firm Size") legend(label(1 "Data") label(2 "Linear Fit") label(3 "Quadratic Fit"))
graph export "Scatter_Plot.png", replace


*基准回归模型（控制年份和行业固定效应）

reg rd_intensity female_ceo log_assets leverage tangibility current_ratio year_dummy* ind_dummy*, vce(robust)
est store Model1
outreg2 using "Regression_Results.rtf", replace ctitle("Baseline") addtext(Year FE, Yes, Industry FE, Yes)

/* 异方差检验 */
estat hettest // 若p<0.05，存在异方差，应使用稳健标准误差

*调节变量示例，本doflie文件暂无调节变量相关数据
*=调节变量1：企业年龄（假设变量名为firm_age)
gen mod1 = firm_age
reg rd_intensity c.female_ceo##c.mod1 log_assets leverage tangibility current_ratio year_dummy* ind_dummy*, vce(robust)
est store Model2

* 调节变量2：市场竞争强度（假设用HHI指数衡量，变量名为hhi） *
gen mod2 = hhi
reg rd_intensity c.female_ceo##c.mod2 log_assets leverage tangibility current_ratio year_dummy* ind_dummy*, vce(robust)
est store Model3
* 输出结果 *
outreg2 [Model1 Model2 Model3] using "Moderator_Results.rtf", replace