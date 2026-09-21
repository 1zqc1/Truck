// create_paper.js —— 生成论文草稿《考虑液体晃动的半挂液罐车侧翻预警研究》
const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
    HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType,
    Header, Footer, PageNumber, TabStopType, TabStopPosition } = require('docx');

// =================== 内容数据 ===================
const TITLE = '考虑液体晃动的半挂液罐车侧翻预警研究';
const AUTHORS = '作者姓名';
const AFFILIATION = '（XX大学 XX学院，省市 邮编）';

const ABSTRACT = '为解决半挂液罐车在运输过程中的侧翻预警问题，基于TruckSim与MATLAB/Simulink' +
    '联合仿真平台搭建了七自由度半挂液罐车动力学模型，并引入LDP线性等效双摆模型模拟液体晃动效应' +
    '。以横向载荷转移率（LTR）的绝对值0.7作为侧翻预警阈值，在鱼钩、双移线和阶跃转向三种典型侧翻' +
    '工况下，叠加道路横坡，共采集了37组仿真数据作为训练和测试数据集。选取侧向加速度、横摆角速度、' +
    '挂车侧倾角、纵向车速和方向盘转角共5个特征参数，分别构建了LSTM、CNN和CNN-LSTM三种神经网络' +
    '侧翻预警模型。结果表明：三种模型均表现出优异的预测性能，其中CNN-LSTM模型的预测准确率为' +
    '99.28%，F1值为0.969，AUC值为0.9988，综合性能最优。通过消融实验分析了液体晃动对侧翻预测' +
    '的影响，发现LSTM模型对液体晃动动力学具有良好的自适应学习能力，为液罐车侧翻预警提供了新的' +
    '研究视角。';

const KEYWORDS = '半挂液罐车；液体晃动；神经网络；横向载荷转移率；侧翻预警；联合仿真';
const CLC = 'U 469.5';

// =================== 辅助函数 ===================
function p(text, opts = {}) {
    const runs = [];
    if (typeof text === 'string') {
        runs.push(new TextRun({ text, font: '宋体', size: 24, ...opts }));
    }
    return new Paragraph({
        spacing: { line: 360, before: 0, after: 0 },
        indent: opts.indent ? { firstLine: 480 } : undefined,
        alignment: opts.align || AlignmentType.JUSTIFIED,
        children: runs,
    });
}

function heading(text, level) {
    return new Paragraph({
        heading: level,
        spacing: { before: 240, after: 120 },
        children: [new TextRun({ text, font: '黑体', bold: true,
            size: level === HeadingLevel.HEADING_1 ? 28 : 26 })],
    });
}

function section(title) {
    return heading(title, HeadingLevel.HEADING_1);
}

function subsection(title) {
    return heading(title, HeadingLevel.HEADING_2);
}

// Create a data table
function makeTable(headers, rows, colWidths) {
    const border = { style: BorderStyle.SINGLE, size: 1, color: '000000' };
    const borders = { top: border, bottom: border, left: border, right: border };
    const totalWidth = colWidths.reduce((a, b) => a + b, 0);

    const headerRow = new TableRow({
        children: headers.map((h, i) => new TableCell({
            borders,
            width: { size: colWidths[i], type: WidthType.DXA },
            shading: { fill: 'D9E2F3', type: ShadingType.CLEAR },
            margins: { top: 60, bottom: 60, left: 100, right: 100 },
            children: [new Paragraph({
                alignment: AlignmentType.CENTER,
                children: [new TextRun({ text: h, font: '黑体', size: 20, bold: true })],
            })],
        })),
    });

    const dataRows = rows.map(row => new TableRow({
        children: row.map((cell, i) => new TableCell({
            borders,
            width: { size: colWidths[i], type: WidthType.DXA },
            margins: { top: 40, bottom: 40, left: 80, right: 80 },
            children: [new Paragraph({
                alignment: AlignmentType.CENTER,
                children: [new TextRun({ text: String(cell), font: '宋体', size: 20 })],
            })],
        })),
    }));

    return new Table({
        width: { size: totalWidth, type: WidthType.DXA },
        columnWidths: colWidths,
        rows: [headerRow, ...dataRows],
    });
}

function emptyLine() {
    return new Paragraph({ spacing: { before: 60, after: 60 }, children: [] });
}

// =================== 构建文档 ===================
const doc = new Document({
    styles: {
        default: {
            document: { run: { font: '宋体', size: 24 } },
        },
    },
    sections: [
        // ============ 第一页：标题、摘要、引言 ============
        {
            properties: {
                page: {
                    size: { width: 11906, height: 16838 }, // A4
                    margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
                },
            },
            headers: {
                default: new Header({
                    children: [new Paragraph({
                        alignment: AlignmentType.CENTER,
                        children: [new TextRun({ text: '第XX卷第X期', font: '宋体', size: 18 })],
                    })],
                }),
            },
            footers: {
                default: new Footer({
                    children: [new Paragraph({
                        alignment: AlignmentType.CENTER,
                        children: [
                            new TextRun({ text: '— ', font: '宋体', size: 18 }),
                            new TextRun({ children: [PageNumber.CURRENT], font: '宋体', size: 18 }),
                            new TextRun({ text: ' —', font: '宋体', size: 18 }),
                        ],
                    })],
                }),
            },
            children: [
                // ===== 标题 =====
                new Paragraph({ spacing: { before: 200, after: 80 },
                    alignment: AlignmentType.CENTER,
                    children: [new TextRun({ text: TITLE, font: '黑体', size: 32, bold: true })] }),
                // 作者
                new Paragraph({ spacing: { after: 60 }, alignment: AlignmentType.CENTER,
                    children: [new TextRun({ text: AUTHORS, font: '宋体', size: 24 })] }),
                // 单位
                new Paragraph({ spacing: { after: 160 }, alignment: AlignmentType.CENTER,
                    children: [new TextRun({ text: AFFILIATION, font: '宋体', size: 20 })] }),

                // ===== 摘要 =====
                new Paragraph({ spacing: { before: 120, after: 60 }, indent: { firstLine: 480 },
                    children: [
                        new TextRun({ text: '摘  要：', font: '黑体', size: 22, bold: true }),
                        new TextRun({ text: ABSTRACT, font: '宋体', size: 22 }),
                    ] }),
                new Paragraph({ spacing: { after: 60 }, indent: { firstLine: 480 },
                    children: [
                        new TextRun({ text: '关键词：', font: '黑体', size: 22, bold: true }),
                        new TextRun({ text: KEYWORDS, font: '宋体', size: 22 }),
                    ] }),
                new Paragraph({ spacing: { after: 120 }, indent: { firstLine: 480 },
                    children: [
                        new TextRun({ text: '中图分类号：', font: '黑体', size: 22, bold: true }),
                        new TextRun({ text: CLC, font: '宋体', size: 22 }),
                        new TextRun({ text: '   文献标识码：A', font: '宋体', size: 22 }),
                    ] }),

                emptyLine(),
                // ===== 0 引言 =====
                section('0  引言'),
                p('半挂液罐车是危险化学品公路运输的主要载体，具有载重量大、质心高、运输里程长等特点。' +
                  '与普通货车不同，液罐车在行驶过程中罐内液体在外界激励下会产生晃动，晃动力和力矩反' +
                  '馈至车体后进一步加剧车辆的侧倾运动，显著增大了侧翻风险。据统计，液罐车侧翻事故在' +
                  '危化品运输事故中占据较高比例，造成严重的人员伤亡和环境污染。因此，针对半挂液罐车' +
                  '开展侧翻预警研究具有重要的工程应用价值。'),
                p('针对不同类型车辆的侧翻问题，国内外学者已开展了大量研究。在侧翻预警指标方面，横向' +
                  '载荷转移率（Lateral-load Transfer Rate, LTR）因其计算简便、物理意义明确而被广泛采用' +
                  '。在预警方法方面，传统方法多基于车辆动力学模型和状态估计，近年来随着深度学习技术' +
                  '的发展，基于神经网络的侧翻预警方法受到越来越多的关注。汪佳铭等[1]基于CNN-LSTM神经' +
                  '网络构建了重型自卸车侧翻预警模型，在鱼钩、双移线和阶跃三种工况下取得了98.31%的预' +
                  '测准确率。姚嘉凌等[2]提出了一种基于HMM与神经网络相结合的车辆侧翻预警方法。'),
                p('然而，上述研究主要针对干货车（自卸车、客车等），未考虑液体晃动对侧翻的影响。对于' +
                  '半挂液罐车而言，液体晃动是其区别于普通货车的最显著特征。液体在外界激励下的非线性' +
                  '晃动会改变车辆的载荷分布，产生附加的横向力和侧倾力矩，从而影响侧翻稳定性。因此，' +
                  '有必要针对半挂液罐车的特殊性开展侧翻预警研究。'),
                p('本文以某型六轴半挂液罐车为研究对象，基于TruckSim与MATLAB/Simulink联合仿真平台搭' +
                  '建了七自由度车辆动力学模型，引入LDP（Linear Double Pendulum）线性等效双摆模型模拟' +
                  '液体晃动效应。在鱼钩、双移线和阶跃转向三种典型侧翻工况下，叠加道路横坡，共采集37组' +
                  '仿真数据，以LTR=0.7为预警阈值，分别构建LSTM、CNN和CNN-LSTM三种神经网络侧翻预警模型' +
                  '进行对比分析。进一步通过消融实验探究液体晃动对侧翻预测性能的影响，为液罐车侧翻预警' +
                  '提供理论依据和工程参考。'),
                emptyLine(),

                // ===== 1 影响半挂液罐车侧翻的主要因素 =====
                section('1  影响半挂液罐车侧翻的主要因素'),

                subsection('1.1  半挂液罐车侧翻机理'),
                p('半挂液罐车侧翻是一种复杂的动力学失稳现象，其发生机理主要可以归纳为两类因素：' +
                  '（1）车辆结构设计的静态参数，包括牵引车与挂车的质心高度、悬架类型与刚度、轮胎' +
                  '特性、罐体几何形状等；（2）车辆行驶过程中的动态参数，包括侧向加速度、横摆角速度' +
                  '、侧倾角、质心侧偏角和横向载荷转移率等。其中，横向载荷转移率LTR最能直观反映车' +
                  '辆的侧倾稳定性[3]。'),
                p('半挂液罐车由于罐体安装位置较高，满载时质心高度可达1.8m以上，远高于普通货车。' +
                  '同时，其行驶路况多为高速公路和国省干道，车速较高，在紧急避障或急转弯时极易诱发' +
                  '侧翻。由以往侧翻事故分析可知，横摆角速度、侧倾角、侧向加速度、质心侧偏角和LTR' +
                  '这5个动态参数最能反映车辆侧倾稳定性[4]。'),

                subsection('1.2  液体晃动对侧翻的影响'),
                p('液体晃动是液罐车区别于干货车的最显著动力学特征。当车辆进行转向、制动或加速时，' +
                  '罐内液体在外界惯性力激励下产生晃动，其运动呈现强非线性和多模态特征。液体晃动对' +
                  '车辆侧翻的影响主要体现在两个方面：一是晃动力和力矩作用在罐体上，直接改变车辆的' +
                  '侧倾力矩平衡；二是晃动导致罐体有效质心位置发生偏移，间接影响车辆的横摆和侧倾响' +
                  '应。研究表明，充液比约为70%时液体晃动幅度最大，对车辆稳定性的影响最为显著[5]。'),
                p('为量化液体晃动效应，本文采用LDP线性等效双摆模型。该模型将液体晃动等效为两个具有' +
                  '不同固有频率的单摆——主摆（承载约75%液体质量，固有频率4.22 rad/s）和次摆（承载约' +
                  '25%液体质量，固有频率7.38 rad/s），通过双摆的摆角和摆速来计算液体对罐体施加的横' +
                  '向力F_slosh和侧倾力矩M_slosh，从而将液体晃动效应耦合到车辆动力学方程中。'),

                subsection('1.3  横向载荷转移率'),
                p('本文选择以半挂液罐车的LTR作为侧翻稳定性指标。LTR定义为左右侧车轮垂向载荷之差与' +
                  '总垂向载荷之比，其计算公式为：LTR = (∑(F_right - F_left)) / (∑(F_right + F_left))。' +
                  'LTR的取值范围为[-1, +1]。当LTR=0时，表示左右侧车轮载荷相等，车辆处于理想的稳定' +
                  '状态；当LTR→±1时，表示一侧车轮即将或已经离地，车辆处于侧翻临界状态或已发生侧翻。' +
                  '参考相关研究，本文取LTR的绝对值为0.7作为侧翻预警阈值，即当|LTR|≥0.7时判定车辆' +
                  '存在侧翻风险，发出预警信号。'),
                emptyLine(),

                // ===== 2 车辆仿真模型搭建与数据预处理 =====
                section('2  车辆仿真模型搭建与数据预处理'),

                subsection('2.1  TruckSim半挂液罐车仿真模型'),
                p('通过查阅实车资料确定车辆主要参数后，利用TruckSim 2022动力学仿真软件搭建半挂液罐' +
                  '车整车动力学模型。车辆模型由牵引车和半挂罐车两部分组成，通过第五轮（鞍座）铰接。' +
                  '牵引车选用4×2驱动形式，整备质量7500kg；半挂罐车整备质量6500kg，满载液体货物质量' +
                  '20000kg，总质量26500kg。整车七自由度包括：牵引车侧向速度、横摆角速度、侧倾角与' +
                  '侧倾角速度，以及挂车铰接角、侧倾角与侧倾角速度。车辆仿真模型的主要参数如表1所示。'),
                emptyLine(),
                p('表1  半挂液罐车仿真模型主要参数', { align: AlignmentType.CENTER, indent: false }),
                emptyLine(),
                makeTable(
                    ['参数', '数值', '参数', '数值'],
                    [
                        ['牵引车质量/kg', '7 500', '挂车总质量/kg', '26 500'],
                        ['牵引车质心高度/m', '1.10', '挂车质心高度/m', '1.80'],
                        ['牵引车侧倾惯量/(kg·m²)', '4 500', '挂车侧倾惯量/(kg·m²)', '12 000'],
                        ['牵引车横摆惯量/(kg·m²)', '18 000', '挂车横摆惯量/(kg·m²)', '85 000'],
                        ['前悬架刚度/(N·m⁻¹)', '250 000', '挂车悬架刚度/(N·m⁻¹)', '400 000'],
                        ['前轮侧偏刚度/(N·rad⁻¹)', '180 000', '挂车轮距/m', '1.86'],
                        ['前轮距/m', '2.05', '鞍座前置距/m', '0.30'],
                        ['牵引车轴距/m', '3.80', '挂车轴距/m', '8.50'],
                    ],
                    [2300, 2300, 2300, 2300]
                ),
                emptyLine(),

                subsection('2.2  LDP液体晃动等效双摆模型'),
                p('LDP模型将罐内液体晃动等效为两个正交布置的单摆系统。充液比设为70%（充液比在' +
                  '60%~80%时液体晃动的自由液面最大，对车辆稳定性影响最为显著）。主摆承载75%的液体' +
                  '质量（15000kg），等效摆长0.55m，固有频率4.22rad/s，阻尼比0.07；次摆承载25%的液体' +
                  '质量（5000kg），等效摆长0.18m，固有频率7.38rad/s，阻尼比0.05。液体晃动产生的横向' +
                  '力F_slosh和侧倾力矩M_slosh作为外部输入力施加在挂车簧载质心处，从而将液体晃动效应' +
                  '耦合到车辆动力学方程中。'),

                subsection('2.3  联合仿真工况设计'),
                p('为获取模型训练所需的数据集，在TruckSim中设置了37组仿真工况，涵盖三种典型的侧翻' +
                  '测试工况：阶跃转向（Step Steer）、双移线（Double Lane Change，ISO 3888标准）和' +
                  '鱼钩（Fishhook，NHTSA FMVSS 126标准），并叠加道路横坡以模拟弯道超高等实际道路' +
                  '条件。阶跃转向工况模拟紧急转向场景，车速范围为60~100km/h，方向盘转角范围为60°~' +
                  '180°；双移线工况模拟紧急避障场景；鱼钩工况模拟先急转后反向急转的极限侧翻激励，' +
                  '转向幅值90°~270°、转向速率720°/s；横坡工况在90°临界阶跃转向基础上叠加-6%~+6%的' +
                  '道路横坡。所有工况的仿真步长设置为0.001s，数据输出步长为0.01s。各工况的汇总结果' +
                  '如表2所示。'),
                emptyLine(),
                p('表2  仿真工况汇总及结果', { align: AlignmentType.CENTER, indent: false }),
                emptyLine(),
                makeTable(
                    ['工况类型', '组数', '车速/(km/h)', '转向幅值/(°)', '横坡/%', '安全/警告/侧翻'],
                    [
                        ['阶跃转向', '12', '60~100', '60~180', '0', '3/1/8'],
                        ['双移线', '2', '70~100', '—', '0', '0/2/0'],
                        ['鱼钩', '16', '60~90', '90~270', '0', '2/2/12'],
                        ['横坡叠加', '7', '80', '90', '-6~+6', '0/5/2'],
                        ['合计', '37', '60~100', '—', '—', '5/10/22'],
                    ],
                    [1500, 1100, 1400, 1500, 1200, 1500]
                ),
                emptyLine(),

                subsection('2.4  数据预处理'),
                p('从37组TruckSim仿真数据中提取侧向加速度Ay、横摆角速度AVz、挂车侧倾角Roll2、' +
                  '纵向车速Vx和方向盘转角Steer_SW共5个特征参数，同时计算LTR作为模型预测标签。' +
                  '采用滑动窗口方法构建监督学习数据集：取前50个时间步（对应0.5s时间窗口）作为模型' +
                  '输入序列，预测未来10个时间步（0.1s）的LTR值。所有数据先进行Z-score标准化处理，' +
                  '使每个特征的均值为0、标准差为1。将数据集按60%/20%/20%的比例划分为训练集、验证集' +
                  '和测试集。为缓解样本不平衡问题，对训练集中|LTR|≥0.7的危险样本进行上采样，使其' +
                  '占比约30%。'),
                emptyLine(),

                // ===== 3 车辆侧翻预警模型搭建 =====
                section('3  车辆侧翻预警模型搭建'),

                subsection('3.1  神经网络模型结构'),
                p('为全面评估不同神经网络架构在半挂液罐车侧翻预警任务上的表现，本文构建了三种' +
                  '模型进行对比：（1）LSTM模型——采用单层LSTM网络（64个隐藏单元）结合Dropout层和全' +
                  '连接层进行LTR回归预测；（2）CNN模型——采用两层一维卷积层（128和64个卷积核，核' +
                  '大小3）结合全局最大池化层和全连接层；（3）CNN-LSTM混合模型——先通过一维卷积层' +
                  '（128个卷积核）进行特征提取，再经过两层LSTM（64和32个隐藏单元）处理时序特征，' +
                  '最后通过全连接层输出预测值。'),
                p('三种模型均采用Adam优化器进行训练，初始学习率为0.001，采用分段式学习率衰减策略' +
                  '（每20轮衰减至50%），最大训练轮数为80轮，批次大小为64。损失函数采用均方误差' +
                  '（MSE），同时监控验证集损失以防止过拟合。'),

                subsection('3.2  模型性能评价指标'),
                p('本文采用多个评价指标从不同维度评估模型性能：（1）回归指标——均方根误差RMSE和' +
                  '决定系数R²，衡量模型预测LTR值的准确性；（2）分类指标——以|LTR|=0.7为二分类阈值' +
                  '，计算准确率（Accuracy）、精确率（Precision）、召回率（Recall）和F1分数；（3）' +
                  'ROC曲线下面积AUC——衡量模型在不同阈值下的综合判别能力。'),

                subsection('3.3  三模型对比结果'),
                p('三种模型在TruckSim测试集上的性能对比结果如表3所示。实验结果表明：三种神经网络' +
                  '模型均表现出优异的侧翻预警能力，AUC值均超过0.997。其中，CNN-LSTM混合模型在回归' +
                  '精度（R²=0.9821）和分类F1分数（0.969）上均取得最优表现，且准确率（99.28%）和AUC值' +
                  '（0.9988）也为三者最高；LSTM模型次之（R²=0.9784，F1=0.955）；CNN模型在回归精度上' +
                  '与LSTM接近（R²=0.9794），但分类F1分数（0.939）相对较低，主要是由于其在临界样本上' +
                  '的精确率略低所致。'),
                p('上述结果表明，在数据量充足的情况下，CNN-LSTM混合模型能够充分发挥CNN的局部特征' +
                  '提取能力和LSTM的时序建模能力，其综合性能优于单一神经网络，这与汪佳铭等[1]在重型' +
                  '自卸车上的研究结论一致。相较于早期仅使用14组数据（约2845个训练序列）时CNN-LSTM未' +
                  '能体现优势，本次扩充到37组数据（约18056个训练序列）后，混合模型的优势得以充分显现，' +
                  '说明充足的训练数据是发挥复杂网络结构潜力的关键。'),

                emptyLine(),
                p('表3  三模型性能对比（TruckSim测试集）', { align: AlignmentType.CENTER, indent: false }),
                emptyLine(),
                makeTable(
                    ['模型', 'RMSE', 'R²', '准确率/%', '精确率/%', '召回率/%', 'F1', 'AUC'],
                    [
                        ['LSTM', '0.0533', '0.9784', '98.92', '93.39', '97.62', '0.955', '0.9979'],
                        ['CNN', '0.0521', '0.9794', '98.50', '89.78', '98.33', '0.939', '0.9985'],
                        ['CNN-LSTM', '0.0485', '0.9821', '99.28', '96.68', '97.14', '0.969', '0.9988'],
                    ],
                    [1600, 1200, 1100, 1200, 1200, 1200, 900, 1100]
                ),
                emptyLine(),

                // ===== 4 消融实验 =====
                section('4  消融实验：液体晃动影响分析'),
                p('为探究液体晃动对侧翻预测性能的影响，本文设计了消融实验。利用七自由度+LDP离线' +
                  '仿真模型，在120组安全工况（5种车速×3种横坡×2种工况类型×4个转向幅值）下分别运行' +
                  '两次仿真：一次包含完整的LDP液体晃动动力学（F_slosh和M_slosh参与车辆动力学方程），' +
                  '另一次关闭液体晃动模块（F_slosh=0, M_slosh=0）。两组仿真使用完全相同的车辆参数、' +
                  '工况设置和随机种子，唯一区别在于液体晃动动力学的有无。'),
                p('将两组数据分别构建序列数据集（各173,040个样本），使用完全相同的LSTM网络架构' +
                  '（64个LSTM单元、相同训练参数）进行独立训练和测试。消融实验结果如表4所示。'),
                emptyLine(),
                p('表4  消融实验结果（7-DOF仿真数据集）', { align: AlignmentType.CENTER, indent: false }),
                emptyLine(),
                makeTable(
                    ['动力学模型', 'RMSE', 'R²', '准确率/%', 'F1'],
                    [
                        ['含液体晃动(LDP)', '0.0202', '0.9951', '99.36', '0.996'],
                        ['无液体晃动(关闭LDP)', '0.0093', '0.9989', '99.87', '0.999'],
                    ],
                    [2800, 1800, 1600, 1600, 1200]
                ),
                emptyLine(),
                p('实验结果表明：（1）LSTM模型在有无液体晃动的两种动力学场景下均表现出极高的预测' +
                  '精度（F1≥0.996），说明LSTM网络对车辆侧翻状态具备良好的学习能力和泛化性能；' +
                  '（2）无液体晃动场景的预测精度略高于含晃动场景（F1差值为-0.003），这是因为液体' +
                  '晃动引入了额外的非线性和随机性，增加了侧翻状态预测的难度；（3）含晃动场景下F1值' +
                  '仅下降0.003，表明LSTM网络可以在训练过程中隐式学习液体晃动的动力学特征，即使不在' +
                  '输入特征中显式包含晃动状态变量，仍能适应晃动对车辆动力学的扰动。'),
                p('以上消融实验结果为后续液罐车侧翻预警模型的进一步优化提供了有价值的方向参考：' +
                  '可以在LSTM基础上，通过增加训练数据多样性、引入注意力机制或结合物理信息网络等' +
                  '方法，进一步提升对含液体晃动场景的预测鲁棒性。'),

                emptyLine(),
                // ===== 5 结论 =====
                section('5  结论'),
                p('本文以半挂液罐车为研究对象，基于TruckSim与MATLAB/Simulink联合仿真平台搭建了七' +
                  '自由度车辆动力学模型，引入LDP双摆模型模拟液体晃动效应，构建了LSTM、CNN和CNN-LSTM' +
                  '三种神经网络侧翻预警模型，并通过消融实验分析了液体晃动对预测性能的影响。主要结论' +
                  '如下：'),
                p('（1）三种神经网络模型在TruckSim测试集上均表现出优异的侧翻预警性能：LSTM模型F1值' +
                  '为0.955，AUC值为0.9979；CNN模型F1值为0.939，AUC值为0.9985；CNN-LSTM模型F1值为' +
                  '0.969，AUC值为0.9988。CNN-LSTM混合模型综合表现最优，三种模型的AUC值均接近0.998，' +
                  '表明基于数据驱动的神经网络侧翻预警方法具有较高的准确性和可靠性。'),
                p('（2）消融实验表明，液体晃动对LSTM模型的侧翻预测性能影响有限（F1值仅下降0.003），' +
                  'LSTM网络对液体晃动动力学具有良好的自适应学习能力。但含晃动场景的预测精度略低于' +
                  '无晃动场景，说明液体晃动引入的额外非线性仍在客观上增加了侧翻预测的难度。'),
                p('（3）本文研究仍存在以下局限性，值得后续深入探索：实验数据主要来源于仿真平台，' +
                  '与真实道路场景存在差距，未来可通过实车试验数据验证模型的工程适用性；当前仅使用' +
                  '了5个车辆状态特征，后续可引入罐内液体晃动状态（如液面高度、晃动角度）作为显式' +
                  '输入特征，研究其对模型性能的影响；可进一步探索引入注意力机制或物理信息约束的' +
                  '混合模型以提升对晃动场景的鲁棒性。'),
                emptyLine(),

                // ===== 参考文献 =====
                section('参考文献'),
                p('[1] 汪佳铭, 胡明茂, 师国东, 等. 基于CNN-LSTM的重型自卸车侧翻预警模型[J]. ' +
                  '滨州学院学报, 2024, 40(2): 81-89.', { indent: true }),
                p('[2] 姚嘉凌, 李智宏, 田松梅, 等. HMM与神经网络相结合的车辆侧翻预警研究[J]. ' +
                  '机械设计与制造, 2017(11): 178-182.', { indent: true }),
                p('[3] 陈东乐. 重型车辆侧翻因素探讨[J]. 汽车实用技术, 2016(2): 144-145.', { indent: true }),
                p('[4] 廖聪, 吴新烨, 黄红武. 客车半主动悬架防侧翻模糊滑模控制[J]. 厦门大学学报' +
                  '(自然科学版), 2014, 53(3): 373-377.', { indent: true }),
                p('[5] 郑淳心. 液罐车侧翻稳定性研究[D]. 长春: 吉林大学, 2018.', { indent: true }),
                p('[6] LIAO Z W, GONG A H, HU M M, et al. Rollover analysis of heavy dump ' +
                  'truck considering cargo mass center variation[J]. Journal of Hubei ' +
                  'University of Automotive Technology, 2019, 33(4): 20-24.', { indent: true }),
                p('[7] JIN Z, LI J, HUANG Y, et al. Study on rollover index and stability ' +
                  'for a triaxle bus[J]. Chinese Journal of Mechanical Engineering, 2019, 32: 1-15.', { indent: true }),
                emptyLine(),

                // ===== 英文部分 =====
                new Paragraph({ spacing: { before: 360, after: 120 }, alignment: AlignmentType.CENTER,
                    children: [new TextRun({ text: 'Rollover Warning Study of Semi-Trailer Tank Truck ' +
                        'Considering Liquid Sloshing', font: 'Times New Roman', size: 28, bold: true })] }),
                new Paragraph({ spacing: { after: 60 }, alignment: AlignmentType.CENTER,
                    children: [new TextRun({ text: 'Author Name', font: 'Times New Roman', size: 24 })] }),
                new Paragraph({ spacing: { after: 120 }, alignment: AlignmentType.CENTER,
                    children: [new TextRun({ text: '(School of XX, XX University, City Postcode, China)',
                        font: 'Times New Roman', size: 20 })] }),
                new Paragraph({ spacing: { after: 60 }, indent: { firstLine: 480 },
                    children: [
                        new TextRun({ text: 'Abstract: ', font: 'Times New Roman', size: 22, bold: true }),
                        new TextRun({ text: 'To address the rollover warning problem of ' +
                            'semi-trailer tank trucks, a 7-DOF vehicle dynamics model is established ' +
                            'using TruckSim and MATLAB/Simulink co-simulation platform, with an LDP ' +
                            '(Linear Double Pendulum) model to simulate liquid sloshing effects. ' +
                            'Taking the lateral load transfer rate (LTR) of 0.7 as the warning threshold, ' +
                            '37 sets of simulation data are collected under fishhook, double lane change, ' +
                            'and step steer maneuvers with road superelevation. Three neural network models ' +
                            '(LSTM, CNN, and CNN-LSTM) are constructed using 5 vehicle state features. ' +
                            'Results show that the CNN-LSTM model achieves the best performance with an ' +
                            'accuracy of 99.28%, F1 score of 0.969, and AUC of 0.9988. Ablation experiments ' +
                            'reveal that the LSTM model exhibits strong adaptive learning capability to ' +
                            'liquid sloshing dynamics.',
                            font: 'Times New Roman', size: 22 }),
                    ] }),
                new Paragraph({ spacing: { after: 120 }, indent: { firstLine: 480 },
                    children: [
                        new TextRun({ text: 'Key words: ', font: 'Times New Roman', size: 22, bold: true }),
                        new TextRun({ text: 'semi-trailer tank truck; liquid sloshing; neural network; ' +
                            'lateral load transfer rate; rollover warning; co-simulation',
                            font: 'Times New Roman', size: 22 }),
                    ] }),
            ],
        },
    ],
});

// =================== 保存 ===================
const outPath = 'c:/Users/LENOVO/tanker_trucksim_cosim/docs/论文草稿.docx';
const outDir = 'c:/Users/LENOVO/tanker_trucksim_cosim/docs';
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

Packer.toBuffer(doc).then(buffer => {
    fs.writeFileSync(outPath, buffer);
    console.log('论文草稿已保存: ' + outPath);
}).catch(err => {
    console.error('生成失败:', err);
    process.exit(1);
});
