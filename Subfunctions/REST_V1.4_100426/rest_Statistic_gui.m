function varargout = rest_Statistic_gui(varargin)
%   varargout = rest_Statistic_gui(varargin)
%   Statistical Analysis GUI.
%   By YAN Chao-Gan 100401.
%   State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
%	http://www.restfmri.net
% 	Mail to Authors:  <a href="ycg.yan@gmail.com">YAN Chao-Gan</a>
%	Version=1.0;
%	Release=200100401;
%--------------------------------------------------------------------------

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @rest_Statistic_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @rest_Statistic_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end

function rest_Statistic_gui_OpeningFcn(hObject, eventdata, handles, varargin)

handles.output = hObject;

guidata(hObject, handles);

function varargout = rest_Statistic_gui_OutputFcn(hObject, eventdata, handles) 

varargout{1} = handles.output;

function btnTtest1_Callback(hObject, eventdata, handles)
rest_ttest1_gui;

function btnTtestpaired_Callback(hObject, eventdata, handles)
rest_ttestpaired_gui;

function btnTtest2cov_Callback(hObject, eventdata, handles)
rest_ttest2cov_gui;

function btnAncova_Callback(hObject, eventdata, handles)
rest_ancova1_gui;

function btnCorr_Callback(hObject, eventdata, handles)
rest_corr_gui;


